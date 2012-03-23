# coding: utf-8

require 'logger'
require 'yaml'
require 'stringio'
require 'fileutils'

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

  def start( selection )

    result = nil

    prepare

    @selection = selection || ''

    info 'Starting'
    start_time = Time.now

    info "Using: '#{@data_dir}' for selection '#{@selection}'"

    # step 1: read the mapping configuration (maps metadata to DC and Scope)
    read_mapping

    # step 2: read and parse the metadata file (@tree is built)
    if collect_metadata

      info "Creating tree file: #{@tree.print('tree.txt')}"
      info "Creating metadata file: #{@tree.print_metadata('metadata.out.txt', @mapping)}"
    end

    # step 3: download files
    download_files

    run = IngestRun.new :created_at => Time.now
    ApplicationStatus.instance.run = run

    # step 4: create Dublin Core records and a dc_mapping file (maps a record to it's DC file)
    create_dc

    # step 5: create an ingest_run, ingest_configs and ingest_objects
    write_ingest_config run

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
    @mapping_file = Application.dir + '/config/sharepoint/KADOC_Archives.mapping.csv'
    @ingest_template = Application.dir + '/config/sharepoint/KADOC_config.template'
    @metadata_file = 'tree.dat'

  end

  protected

  def tree
    @tree ||= SharepointMetadataTree.new
  end

  def read_mapping
    info "Reading mapping file '#{@mapping_file}'"
    @mapping = SharepointMapping.new @mapping_file
  end

  def collect_metadata
    if File.exists? @metadata_file
      info "Loading metadata from '#{@metadata_file}'"
      @tree = SharepointMetadataTree.open @metadata_file
      false
    else
      info "Collecting metadata for '#{@selection}'"
      tree.collect_metadata @mapping, @selection
      tree.save @metadata_file
      true
    end
  end

  def download_files
    info "Downloading files to '#{@data_dir}'"
    tree.download_files( @selection, @data_dir )
  end

  def create_dc( dir = 'dc_data' )

    info "Creating metadata in '#{dir}' and mapping file '#{@metadata_map}'"

    FileUtils.mkdir_p dir
    dc_map = {}

    tree.visit do |phase, node, options|

      if phase == :before

        options[:count] ||= 0

        next unless node.content
        next unless node.content.is_described?

        file_name = node.content.create_dc dir, mapping
        dc_map[node.content.relative_path] = file_name

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
      config = fp.readlines( nil ).join('\n')
    end

    cfg_hash = YAML.load(config)
    cfg_hash.key_strings_to_symbols! recursive: true
    cfg_hash[:common][:packaging][:location] = "#{@data_dir}"
    cfg_hash[:common][:packaging][:selection] = "#{@selection}"

    cfg_hash[:metadata] = { file: @metadata_map }

    run.init_config cfg_hash
    run.status = Status::New
    run.save
    info "Created run ##{run.id}"

    file_config = write_file_configuration run
    xml_config = write_xml_configuration run
    info "Created configurations ##{file_config.id} - ##{xml_config.id}"

    create_file_objects file_config, xml_config
    tree.save 'tree.dat' # ingest object IDs have been added to the metadata

    run.save

    run

  end

  def create_file_objects( config, xml_config )

    xml_dir = File.join @work_dir, 'xml_files'

    im_map = {}
    ar_map = {}

    tree.visit( tree[@selection] ) do |phase, node, options|

      metadata = node.content

      if phase == :before

        if metadata
          options[:accessright_model] = metadata.accessright_model if metadata.accessright_model
          ar_map[metadata.relative_path] = options[:accessright_model]
        end

        attributes = { name: node.name }

        if node.has_children?

          if metadata #and metadata.is_described?

            if options[:xml_doc]
              xml_node = options[:xml_doc].create_node( 'folder', :attributes => attributes )
              options[:this_node] = xml_node
              options[:xml_container_node] << xml_node if options[:xml_container_node]
            end

            doc = XmlDocument.new
            doc.root = doc.create_node 'tree'
            doc.add_processing_instruction('xml-stylesheet', 'type="text/xsl" href="/view/sharepoint/viewer.xsl"')

            options[:xml_doc] = doc
            options[:xml_container_node] = doc.root

            options[:xml_root_obj] = node

            attributes['path'] = metadata.relative_path

          end

          xml_node = options[:xml_doc].create_node( 'folder', :attributes => attributes )
          options[:xml_container_node] << xml_node
          options[:xml_container_node] = xml_node

        elsif metadata and metadata.is_file?

          metadata.label_prefix = (metadata.label_prefix.to_s + ' ' + options[:label_prefix].to_s).strip

          file = File.join(@data_dir, metadata.relative_path)

          if test ?f, file
            create_ingest_object file, config, metadata
            im_map[file] = metadata.ingest_model
          else
            error "Expected to find the file '#{file}', but it did not exist or is a directory. Object skipped."
          end

          if (parent_xml_node = options[:xml_container_node])
            attributes['oid'] = metadata[:ingest_object_id].to_s if metadata and metadata[:ingest_object_id]
            xml_node = options[:xml_doc].create_node('file', :attributes => attributes )
            parent_xml_node << xml_node

          end

        end

        if metadata and metadata.simple_content_type == :mmap
          options[:label_prefix] = metadata.label
        end

      else # phase == :after

        FileUtils.mkdir_p xml_dir

        if metadata and options[:xml_root_obj] == node and (doc = options[:xml_doc])

#          if doc.has_element?('file[@oid]') || doc.has_element?('folder[@oid]')

            file = File.join xml_dir, "map_#{metadata[:index].to_s}.xml"
            options[:xml_doc].save file

            create_ingest_object file, xml_config, metadata, true

            options[:this_node]['oid'] = metadata[:ingest_object_id].to_s if options[:this_node]
            options[:this_node]['id'] = metadata[:index].to_s if options[:this_node]

#          end

          doc.xpath('//folder[@oid]').each do |folder_node|
            file = File.join xml_dir, "map_#{folder_node['id'].to_s}.xml"
            folder = XmlDocument.open(file)
            folder.root['oid'] = metadata[:ingest_object_id].to_s
            folder.save file
          end

        end

      end

    end

    config.save
    xml_config.save

    File.open(@ingestmodel_map, 'w:utf-8') do |fp|
      fp.puts JSON.pretty_generate im_map
    end unless im_map.empty?

    File.open(@accessright_map, 'w:utf-8') do |f|
      f.puts JSON.pretty_generate ar_map
    end unless ar_map.empty?

  end

  def create_ingest_object( file, config, metadata, is_map = false )

    obj = IngestObject.new file, config.checksum_type

    obj.status = Status::Initialized
    obj.label = metadata.relative_path if is_map
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

  def write_file_configuration( run )
    cfg = {
        match:                  "\\/(([^\\/]+\\/)*)([^\\/]+)$",
        ingest_model:           { file: @ingestmodel_map },
        ingest_type:            :SHAREPOINT_DATA,
        metadata:               { file: @metadata_map },
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

  def write_xml_configuration( run )
    cfg = Hash.new

    cfg[:match] = "(#{File.expand_path(@work_dir).escape_for_regexp}\\/xml_files\\/)([^\\/]+\.xml)$"
    cfg[:ingest_model] = { model: 'Archiveren zonder manifestations' }
    cfg[:ingest_type] = :SHAREPOINT_XML
    cfg[:metadata] = { file: @metadata_map }

    config = IngestConfig.new
    config.init cfg
    config.save

    #noinspection RubyResolve
    run.ingest_configs << config

    config
  end

end
