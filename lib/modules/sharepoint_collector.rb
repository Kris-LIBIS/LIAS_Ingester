require 'logger'
require 'iconv'
require 'nokogiri'
require 'csv'
require 'set'
require 'fileutils'
require 'json'

require_relative '../tools/xml_writer'

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

class SharepointCollector
  include XmlWriter

  REF_MAPPER = {
    :content_type   => :ows_ContentType,
    :ar_model       => :ows_Access_x0020_rights_x0020_model,
    :ingest_model   => :ows_Ingestmodel,
    :file_path      => :ows_FileRef,
    :file_name      => :ows_FileLeafRef,
    :dir_name       => :ows_FileDirRef,
    :relative_path  => :ows_Referentie,    ## this field seems to be unreliable in the sample data
    :url            => :ows_EncodedAbsUrl
  }

  attr_reader :metadata
  attr_reader :md_mapping
  attr_reader :tree
  
  def initialize( selection = '', ingestmodel_map = 'ingestmodel.map', metadata_map = 'metadata.map')
    @selection, @ingestmodel_map, @metadata_map = selection, ingestmodel_map, metadata_map
  end

  def read_mapping( mapping_file )
    @md_mapping = {}

    CSV.foreach( mapping_file ) do |row|
      next unless row[1]
      next unless row[1].match(/^ows_/)

      name = row[0] ? row[0].strip : nil
      label = row[1].strip.to_sym
      tag = row[2] ? row[2].strip : nil

      mapping = {}
      mapping[:name] = name if name
      if tag
        if tag.match(/^<dc:([^.>]+)>/)
          mapping[:tag] = "dc:#{$1}"
        elsif tag.match(/^<dc:[^.]+\.([^.>]+)>/)
          mapping[:tag] = "dcterms:#{$1}"
        end
        if tag.match(/^"(.*)"\s*</)
        mapping[:prefix] = $1
        end
        if tag.match(/>\s*"(.*)"$/)
        mapping[:postfix] = $1
        end
      end
      if ref = REF_MAPPER.invert[label]
      mapping[:ref] = ref
      end
      @md_mapping[label] = mapping.empty? ? nil : mapping

    end
  end

  def collect_metadata( metadata_file )
    ignored_tags = Set.new
    tags_not_found = Set.new
    metadata = {}
    count = 0
    printf 'Collecting metadata: ......'
    File.open(metadata_file, 'r:utf-8').each_line($/) do |l|
    #      line = Iconv.conv('utf-8', 'latin1', l).chomp.strip
      line = l.chomp.strip
      $logger.debug(self.class) { "line: '#{line}'" }
      unless line =~ /^\s*$/
        line_array = line.split('=').each { |x| x.strip! }
        $logger.debug(self.class) { "line_array: '#{line_array.inspect}'" }
        label = line_array[0].to_sym
        value = line_array[1]
        next unless value
        unless @md_mapping.has_key?(label)
        tags_not_found.add label
        next
        end
        mapping = @md_mapping[label]
        unless mapping
        ignored_tags.add label
        next
        end
        metadata[label] = value
        $logger.debug(self.class) { "value: '#{line_array[1]}'" }
      else
        if @selection.empty? or get_relative_path( metadata ) =~ /^#{@selection}/
          $logger.debug(self.class) { "metadata: '#{metadata.inspect}''" }
          @metadata ||= []
          @metadata << metadata
          count += 1
          "\b\b\b\b\b\b".display
          printf "%6d", count
          $stdout.flush
        end
        metadata = {}
      end
    end
    @metadata << metadata unless metadata.empty?
    puts ' Records processed.'
    $stdout.flush
    ignored_tags.each do |tag|
      $logger.warn(self.class) { "Ignored '#{tag}' because no mapping available." }
    end
    tags_not_found.each do |tag|
      $logger.error(self.class) { "Label '#{tag}' not found in the mapping table."}
    end
  end

  def print_metadata( file_name )
    File.open(file_name,'w:utf-8') do |f|
      @metadata.each_with_index do |m,i|
        f.printf "%6d -------------------------------------------------------------------------\n", i
        m.each do |label, value|
          name = ''
          if mapping = @md_mapping[label]
            name = mapping[:name] || ''
          end
          if ref = REF_MAPPER.invert[label]
            name += " [#{ref.to_s}]"
          end
          f.printf " %38s : %s\n", name, value
        end
      end
    end
  end

  def create_dc( dir = '.' )
    FileUtils.mkdir_p dir
    dc_map = {}
    @metadata.each_with_index do |metadata, i|
      file_path = get_relative_path metadata
      unless file_path
        $logger.error(self.class) { "Could not find path to related object for record ##{i}"}
        next
      end
      doc = create_document
      top_node = create_node 'record', :namespaces => {
        'dc'      => 'http://purl.org/dc/elements/1.1',
        'xsi'     => 'http://www.w3.org/2001/XMLSchema-instance',
        'dcterms' => 'http://purl.org/dc/terms'
        }
      doc.root = top_node
      metadata.each do |label, value|
        m = @md_mapping[label]
        tag = m[:tag]
        next unless tag
        v = (@md_mapping[label][:prefix] || '') + value + (@md_mapping[label][:postfix] || '')
        top_node << create_text_node( tag, v )
      end
      dc_file = "#{dir}/dc_#{i}.xml"
      save_document doc, "#{dir}/dc_#{i}.xml"
      dc_map[file_path] = dc_file
    end
    File.open(@metadata_map, 'w:utf-8') do |f|
      f.puts JSON.pretty_generate dc_map
    end
  end
  
  def create_tree
    @tree = {}
    @metadata.each_with_index do |metadata, i|
      rp = get_relative_path metadata
      path_list = rp.split '/'
      tree_node = @tree
      path_list.each do |x|
        unless tree_node.has_key? x
          tree_node[x] = {}
        end
        tree_node = tree_node[x]
      end
      tree_node[:index] = i
    end
  end

  def check_tree
    tree = @tree
    tree.each do |key, value|
      if key == :index
      else
      end
    end
  end

  def tree_visitor( tree_node, options = {}, &block )
    tree_node.each do |key, value|
      next if key == :index
      metadata = nil
      if value.has_key? :index
        metadata = @metadata[value[:index]]
        metadata[:index] = value[:index]
      end
      my_options = options.dup
      my_options[:path] ||= []
      my_options[:path] << key
      my_options[:node] = value
      yield key, metadata, my_options
      tree_visitor value, my_options, &block
      my_options[:path].pop
    end
  end

  def print_tree( file_name )
    File.open(file_name,'w:utf-8') do |f|
      tree_visitor( @tree, prefix: '', complex: false ) do |key, metadata, options|
        node_string = '           '
        prefix = '  '
        if metadata
          ingest_type = get_ingest_type( metadata ).to_s[0]
          if not options[:complex]
            ingest_type.upcase!
            if ingest_type == 'C'
              options[:complex] = true
              prefix = '|-'
            end
          else
            prefix = '--'
          end
          node_string = sprintf '%s %6d - ', ingest_type, metadata[:index]
        end
        node_string += sprintf "%s%-130s", options[:prefix], key
        node_string += ' [' + metadata[REF_MAPPER[:content_type]] + ']' if metadata
        f.puts node_string
        options[:prefix] += prefix
      end
    end
  end

  def download_script( file_name )
    File.open( file_name, 'w:utf-8') do |f|
      tree_visitor( @tree ) do |key, metadata, options|
        url = '-'
        file_name = options[:path].join('/')
        if options[:node].keys.tap { |o| o.delete( :index ) }.empty?
            url = metadata[REF_MAPPER[:url]]
        end
        f.puts "#{url}\t#{file_name}"
      end
    end
  end
  
  def write_ingest_config( template, source_dir, file_name )

    config = ''
    File.open(template, 'r:utf-8') do |fp|
      config = fp.readlines( nil ).join('')
    end

    config = config.gsub('@{location}@', source_dir).gsub('@{metadata_file}@', @metadata_map)

    File.open( file_name, "w:utf-8" ) do |f|
      f.puts config
      f.puts
      f.puts 'configurations:'
      f.puts
      write_configurations f
    end
   
  end
  
  def write_configurations( f, tree = @tree )
    im_map = {}
    tree_visitor( @tree, complex: false ) do |key, metadata, options|
      if metadata
        ingest_type = get_ingest_type metadata
        if not options[:complex]
          case ingest_type
          when :complex
            write_complex_configuration f, metadata
            options[:complex] = true
          when :simple
            write_simple_configuration f, metadata
          end
        elsif ingest_type == :simple
          ingest_model = get_ingest_model metadata
          im_map[get_local_path(metadata)] = ingest_model if ingest_type == :simple
        end
      end
    end
    return if im_map.empty?
    File.open(@ingestmodel_map, 'w:utf-8') do |fp|
      fp.puts JSON.pretty_generate im_map
    end
  end
  
  def write_complex_configuration( f, metadata )
    f.puts  " - match:                #{escape_for_regexp(get_relative_path(metadata))}\\/(([^\\/]+\\/)*)([^\\/]+)$"
    f.puts  '   ingest_model:'
    f.puts  "     file:               #{@ingestmodel_map}"
    f.puts  '   metadata:'
    f.puts  "     file:               #{@metadata_map}"
    f.puts  '   mets:'
    f.puts  "     group:              \"['#{escape_for_string(get_relative_path(metadata))}'] + $1.split('/')\""
    f.puts  '     label:              "$3"'
    f.puts  '     usage_type:         view_main'
    f.puts
  end
  
  def write_simple_configuration( f, metadata )
    f.puts  " - match:                #{escape_for_regexp(get_relative_path(metadata))}"
    f.puts  '   ingest_model:'
    f.puts  "     model:              #{get_ingest_model(metadata)}"
    f.puts  '   metadata:'
    f.puts  "     file:               #{@metadata_map}"
    f.puts
  end
  
  def get_relative_path( metadata )
    full_path = metadata[REF_MAPPER[:file_path]]
    return full_path.gsub(/^sites\/lias\/Gedeelde documenten\//,'')
  end
  
  def get_local_path( metadata )
    full_path = metadata[REF_MAPPER[:file_path]]
    selection = @selection
    selection += '/' unless selection[-1] == '/'
    return full_path.gsub(/^sites\/lias\/Gedeelde documenten\/#{selection}/,'')
  end
  
  def get_file_name( metadata )
    return metadata[REF_MAPPER[:file_name]]
  end
  
  def get_ingest_type( md )
    case md[REF_MAPPER[:content_type]]
    when /^Bestanddeel \(folder\)/i
      return :complex
    when /^Bestanddeel of stuk \(document\)/i
      return :simple
    when /^Film/i
      return :simple
    when /^Object/i
      return :simple
    when /^Document/i
      return :simple
    end
    return :unknown
  end
  
  def get_ingest_model( metadata )
    return nil unless metadata
    result = 'Archiveren zonder manifestations'
    if model = metadata[REF_MAPPER[:ingest_model]]
      case model
      when 'jpg-watermark_jp2_tn'
        result = 'Afbeeldingen hoge kwaliteit'
      when 'jpg-watermark_jpg_tn'
        result = 'Afbeeldingen lage kwaliteit'
      end
    end
    return result
  end
  
  def escape_for_regexp( string )
    return string.gsub(/[\.\+\*\(\)\{\}\|\/\\\^\$\"\']/) { |s| '\\' + s[0].to_s }
  end
  
  def escape_for_string( string )
    return string.gsub(/[\'\"]/) { |s| '\\' + s[0].to_s }
  end
end