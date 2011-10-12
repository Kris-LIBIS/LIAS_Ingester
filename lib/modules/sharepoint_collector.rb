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
    collect_metadata

    info "Creating tree file: #{print_tree('tree.txt')}"
    info "Creating metadata file: #{print_metadata('metadata.out.txt')}"

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

    result

  end

  def initialize

    # initialize properties to their default values
    @data_dir = '.'
    @selection = ''

    @ingestmodel_map = 'ingestmodel.map'
    @metadata_map = 'metadata.map'

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
    else
      info "Collecting metadata for '#{@selection}'"
      tree.collect_metadata @mapping, @selection
      tree.save 'tree.dat'
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
    end

  end

  def write_ingest_config run

    info "Creating ingest configurations and objects"
    config = ''
    File.open(@ingest_template, 'r:utf-8') do |fp|
      config = fp.readlines( nil ).join('')
    end

    #noinspection RubyResolve
    cfg_hash = YAML.load(config)
    cfg_hash['common']['packaging']['location'] = "#{@data_dir}"
    cfg_hash['common']['packaging']['selection'] = "#{@selection}"

    cfg_hash['metadata'] = { 'file' => @metadata_map }

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

    tree.visit( tree[@selection] ) do |phase, node, options|

      metadata = node.content

      if phase == :before

        obj = nil

        if metadata and metadata.is_file?

          file = File.join(@data_dir, metadata.relative_path)

          unless test ?f, file

            error "Expected to find the file '#{file}', but it did not exist or is a directory. Object skipped."

          else

            obj = create_ingest_object file, config, metadata

            im_map[file] = metadata.ingest_model

          end

        end

        if parent_xml_node = options[:parent_xml_node]
          attributes = { 'name' => node.name}
          attributes['oid'] = metadata[:ingest_object_id].to_s if metadata and metadata[:ingest_object_id]
          xml_node = options[:xml_doc].create_node ( metadata and metadata.is_file? ? 'file' : 'folder' ),
                                                   :attributes => attributes
          parent_xml_node << xml_node

        end

        if metadata and metadata.is_described? and node.has_children?

          doc = XmlDocument.new
          options[:xml_doc] = doc
          options[:parent_object] = node

          doc.root = doc.create_node 'tree'

          doc.add_processing_instruction('xml-stylesheet', 'type="text/xsl" href="/view/sharepoint/viewer.xsl"')

          xml_node = doc.create_node( 'folder', :attributes => { 'name' => node.name } )
          #noinspection RubyResolve
          doc.root << xml_node
          options[:parent_xml_node] = xml_node

        end

      else # phase == :after

        FileUtils.mkdir_p xml_dir

        if options[:parent_object] == node
          file = File.join xml_dir, "map_#{metadata[:index].to_s}.xml"
          options[:xml_doc].save file

          create_ingest_object file, xml_config, metadata, true

        end

      end

    end

    return if im_map.empty?

    File.open(@ingestmodel_map, 'w:utf-8') do |fp|
      fp.puts JSON.pretty_generate im_map
    end

  end

  def create_ingest_object( file, config, metadata, is_map = false )

    obj = IngestObject.new file, config.checksum_type

    obj.status = Status::Initialized
    obj.label = metadata.relative_path if is_map
    obj.tree_index = metadata[:index].to_i

    config.add_object obj
    config.save

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
    cfg = Hash.new

    cfg[:match] = "\\/(([^\\/]+\\/)*)([^\\/]+)$"
    cfg[:ingest_model] = { file: @ingestmodel_map }
    cfg[:ingest_type] = :SHAREPOINT_DATA
    cfg[:metadata] = { file: @metadata_map }

    config = IngestConfig.new
    config.init cfg
    config.save

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

    run.ingest_configs << config

    config
  end

  def print_tree( file_name )
    File.open(file_name,'w:utf-8') do |f|
      tree.visit( tree.root_node, prefix: '', in_map: false ) do |phase, node, options|
        if phase == :before
          node_string = ' ' * 11
          prefix = ' ' * 2
          prefix = '-' * 2 if options[:in_map]
          if metadata = node.content
            code = metadata.content_code
            code += '*' if metadata.is_described?
            if code == 'M'
              options[:in_map] = true
              prefix = '|-'
            end
            node_string = sprintf '%-2s %6d - ', code, metadata[:index].to_i
          end
          node_string += sprintf "%s%-130s", options[:prefix], node.name
          node_string += ' [' + metadata[:content_type] + ']' if metadata
          f.puts node_string
          options[:prefix] += prefix
        end
      end
    end
    File.expand_path file_name
  end

  def print_metadata( file_name )
    File.open(file_name,'w:utf-8') do |f|
      tree.visit { |phase, node, _| node.content.print_metadata(f, @mapping) if (phase == :before and node.content) }
    end
    File.expand_path file_name
  end

end
