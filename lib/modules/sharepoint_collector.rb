# coding: utf-8

require 'logger'
require 'yaml'
require 'stringio'
require 'fileutils'
require 'roo'

require 'tools/sharepoint_metadata_tree'
require 'tools/string'
require 'models/ingest_run'
require 'models/ingest_config'
require 'ingester_task'
require 'tools/xml_document'
require 'tools/sharepoint_mapping'

require_relative 'initializer'

#noinspection RubyTooManyInstanceVariablesInspection
class SharepointCollector
  include IngesterModule

  # input properties
  attr_accessor :data_dir

  # configuration properties
  attr_accessor :mapping_file
  attr_accessor :mapping
  attr_accessor :ingest_template

  # output properties
  attr_accessor :work_dir
  attr_accessor :ingestmodel_map
  attr_accessor :metadata_map
  attr_accessor :metadata_file
  attr_accessor :accessright_map

  def prepare

  end

  def start(selection)

    result = nil

    prepare

    @selection = selection || ''

    info 'Starting'
    start_time = Time.now

    info "Using: '#@data_dir' for selection '#@selection'"

    # step 1: read the mapping configuration (maps metadata to DC and Scope)
    read_mapping

    # step 2: read and parse the metadata file (@tree is built)
    collect_metadata

    # step 3: download files
    download_files

    run = IngestRun.new :created_at => Time.now
    ApplicationStatus.instance.run = run

    # step 4: create an ingest_run, ingest_configs and ingest_objects
    write_ingest_config run

    # step 5: create Dublin Core records and a dc_mapping file (maps a record to it's DC file)
    create_dc

    info "Creating tree file: #{@tree.print('tree.txt')}"
    info "Creating metadata file: #{@tree.print_metadata('metadata.out.txt', @mapping)}"

    #noinspection RubyResolve
    run.status = Status::Initialized

  rescue Exception => e
    unless run.nil?
      #noinspection RubyResolve
      run.status = Status::InitializeFailed
    end
    handle_exception e

  ensure
    unless run.nil?
      #noinspection RubyResolve
      run.save
      #noinspection RubyResolve
      result = run.id
    end

    info "Run ##{result} processed. Elapsed time: #{elapsed_time start_time}."
    ApplicationStatus.instance.run = nil
    info 'Done'

    return result

  end

  def initialize

    # initialize properties to their default values
    @data_dir = '.'
    @selection = ''

    @ingestmodel_map = 'ingestmodel.map'
    @metadata_map = 'metadata.map'
    @accessright_map = 'accessright_map'

    @work_dir = File.expand_path '.'
    @mapping_url = "https://www.groupware.kuleuven.be/sites/lias/LIAS/Technische%20Werkgroep/SharepointMapping.xlsx"
    @mapping_file = 'SharepointMapping.csv'
    @ingest_template = Application.dir + '/config/sharepoint/KADOC_config.template'
    @metadata_file = 'tree.dat'

  end

  protected

  XML_FILE_NAME = '.lias_map.xml'

  def tree
    @tree ||= SharepointMetadataTree.new
  end

  def read_mapping
    info "Retrieving latest mapping file from SharePoint site '#@mapping_url'"
    local_mapping_file = @mapping_file + '.xlsx'
    SharepointMetadataTree.http_to_file local_mapping_file, @mapping_url, username: tree.search.username, password: tree.search.password, ssl: true
    oo = Excelx.new local_mapping_file
    oo.to_csv @mapping_file
    info "Reading mapping file '#@mapping_file'"
    @mapping = SharepointMapping.new @mapping_file
  end

  def collect_metadata
    if File.exists? @metadata_file
      info "Loading metadata from '#@metadata_file'"
      @tree = SharepointMetadataTree.open @metadata_file
      false
    else
      info "Collecting metadata for '#@selection'"
      tree.collect_metadata @mapping, @selection
      tree.save @metadata_file
      true
    end
  end

  def download_files
    info "Downloading files to '#@data_dir'"
    tree.download_files(@selection, @data_dir)
  end

  def create_dc(dir = 'dc_data')

    info "Creating metadata in '#{dir}' and mapping file '#@metadata_map'"

    FileUtils.mkdir_p dir
    dc_map = {}

    tree.visit do |phase, node, options|

      if phase == :before

        options[:count] ||= 0

        metadata = node.content
        next unless metadata
        next unless metadata.is_described?

        dc_file = metadata.create_dc dir, mapping
        ref_file = metadata.relative_path
        ref_file = File.join(ref_file, XML_FILE_NAME) if node.has_children?
        dc_map[ref_file] = dc_file

        options[:count] += 1
        info "#{options[:count]} DC records created so far ..." if options[:count] % 100 == 0

      end

    end

    File.open(@metadata_map, 'w:utf-8') do |f|
      f.puts JSON.pretty_generate dc_map
    end unless dc_map.empty?

  end

  #noinspection RubyResolve
  def write_ingest_config(run)

    info "Creating ingest configurations and objects"
    config = ''
    File.open(@ingest_template, 'r:utf-8') do |fp|
      config = fp.readlines(nil).join('\n')
    end

    cfg_hash = YAML.load(config)
    cfg_hash.key_strings_to_symbols! recursive: true
    cfg_hash[:common][:packaging][:location] = "#@data_dir"
    cfg_hash[:common][:packaging][:selection] = "#@selection"

    cfg_hash[:metadata] = {file: @metadata_map}

    run.init_config cfg_hash
    run.status = Status::New
    run.save
    info "Created run ##{run.id}"

    config = write_configuration run
    info "Created configuration ##{config.id}"

    create_file_objects config

    tree.save 'tree.dat' # ingest object IDs have been added to the metadata

    run.save

    run

  end

  def create_file_objects(config)

    single_level_xml = true

    im_map = {}
    ar_map = {}

    tree.visit(tree[@selection]) do |phase, node, options|

      metadata = node.content

      if phase == :before

        if metadata
          options[:accessright_model] = metadata.accessright_model if metadata.accessright_model
          ar_map[metadata.relative_path] = options[:accessright_model]
        end

        attributes = {name: node.name}

        # this is a folder
        if node.has_children?

          # remember the folder tree node
          options[:folder_treenode] = node

          # add folder object in parent's xml
          if (doc = options[:xml_doc]) and (parent_node = options[:xml_parent_node])
            xml_node = doc.create_node('folder', :attributes => attributes)
            parent_node << xml_node
            # new xml node is next parent
            options[:xml_parent_node] = xml_node
          end

          if single_level_xml or (metadata and metadata.is_described?)

            # remember xml node in parent
            options[:xml_root_node_in_parent] = options[:xml_parent_node]

            # create new xml object
            doc = XmlDocument.new
            options[:xml_doc] = doc

            # add folder object for this folder to the new tree
            xml_node = doc.create_node('folder', :attributes => attributes)
            doc.root = xml_node
            doc.add_processing_instruction('xml-stylesheet', 'type="text/xsl" href="/view/sharepoint/viewer.xsl"')
            options[:xml_root_node] = xml_node

            # new xml node overrides next parent
            options[:xml_parent_node] = xml_node

          end

          if options[:label_prefix] and metadata and metadata.is_described?
            metadata.label_prefix = options[:label_prefix]
            options[:label_prefix] = metadata.title
          end

          # remember label prefix if we encounter a 'Meervoudige Beschrijving'
          if metadata and metadata.simple_content_type == :mmap
            options[:label_prefix] = metadata.label
          end

        else # no children

          catch :quitFileObject do

            unless metadata
              message = "Object '#{node.name}'"
              if options[:folder_treenode] and options[:folder_treenode].content
                message += " in '#{options[:folder_treenode].content.relative_path}'"
              end
              error message + ' has no sharepoint metadata.'
              throw :quitFileObject
            end

            unless metadata.is_file?
              error "Object '#{metadata.relative_path}' is an empty directory. Object skipped."
              throw :quitFileObject
            end

            file = File.join(@data_dir, metadata.relative_path)

            unless test ?f, file
              error "Find '#{metadata.relative_path}' does not exist. Object skipped."
              throw :quitFileObject
            end

            if options[:label_prefix] and metadata.is_described?
              metadata.label_prefix = options[:label_prefix]
            end

            create_ingest_object file, config, metadata
            im_map[file] = metadata.ingest_model

            if (parent_xml_node = options[:xml_parent_node])
              attributes['oid'] = metadata[:ingest_object_id].to_s if metadata and metadata[:ingest_object_id]
              attributes['id'] = metadata[:index].to_s if metadata and metadata[:index]
              xml_node = options[:xml_doc].create_node('file', :attributes => attributes)
              parent_xml_node << xml_node
            end

          end

        end

      else # phase == :after

        if metadata and node == options[:folder_treenode]

          if options[:xml_parent_node] == options[:xml_root_node]

            index = metadata[:index].to_s

            options[:xml_root_node]['id'] = index

            xml_dir = File.join @data_dir, metadata.relative_path
            FileUtils.mkdir_p xml_dir
            file = File.join xml_dir, XML_FILE_NAME

            options[:xml_doc].save file

            obj = create_ingest_object file, config, metadata, true
            im_map[file] = 'Archiveren zonder manifestations'
            options[:xml_root_node]['oid'] = metadata[:ingest_object_id].to_s
            options[:xml_doc].save file
            obj.recalculate_checksums

            if options[:xml_root_node_in_parent]
              options[:xml_root_node_in_parent]['id'] = index
              options[:xml_root_node_in_parent]['oid'] = metadata[:ingest_object_id].to_s
            end

          end

        end

      end

    end

    config.save

    File.open(@ingestmodel_map, 'w:utf-8') do |fp|
      fp.puts JSON.pretty_generate im_map
    end unless im_map.empty?

    File.open(@accessright_map, 'w:utf-8') do |f|
      f.puts JSON.pretty_generate ar_map
    end unless ar_map.empty?

  end

  def create_ingest_object(file, config, metadata, is_map = false)

    obj = IngestObject.new file, config.checksum_type

    obj.status = Status::Initialized
    obj.label = metadata.label
    #noinspection RubyResolve
    obj.tree_index = metadata[:index].to_i

    config.add_object obj
    obj.save

    ApplicationStatus.instance.obj = obj
    message = "New object ##{obj.id} for #{is_map ? 'map' : 'file'} '#{metadata.relative_path}'"
    message += " - XML file '#{file}'" if is_map
    message += '.'
    info message
    ApplicationStatus.instance.obj = nil

    metadata[:ingest_object_id] = obj.id

    obj

  end

  def write_configuration(run)
    cfg = {
        match:                  "\\/(([^\\/]+\\/)*)([^\\/]+)$",
        ingest_model:           {file: @ingestmodel_map},
        metadata:               {file: @metadata_map},
        accessright_model_map:  @accessright_map
    }

    config = IngestConfig.new
    config.init cfg
    config.save

    #noinspection RubyResolve
    run.ingest_configs << config
    run.save

    config
  end

end
