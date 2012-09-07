# coding: utf-8

require 'json'

require 'ingester_task'
require 'libis/search_factory'
require 'tools/xml_document'
require 'libis/record_factory'

#noinspection RubyResolve
class Metadata
  include IngesterTask
  
  MY_SEARCH_OPTIONS = {:host => 'http://opac.libis.be/X', :target => 'Opac', :base => 'KADOC', :index => 'sig'}
  
  def initialize(cfg)
    raise StandardError.new("input #{cfg} is not an IngestConfig") unless cfg.is_a?(IngestConfig)
    @cfg = cfg
    
    @metadata_map = {}
    if (mf = @cfg.metadata_file)
      @metadata_map = JSON.parse File.open(mf, 'r:utf-8').readlines.join
    end
  end
  
  def get_dc_record(obj)
    if @metadata_map.empty?
      result = get_from_aleph obj
    else
      result = get_from_disk obj
    end
    result
  end
  
  private
  
  def get_from_aleph(obj)
    options = MY_SEARCH_OPTIONS.merge @cfg.get_search_options
    search_term = obj.label
    if options[:term]
      if options[:match]
        search_term = obj.file_name if obj.file_name
        if search_term =~ options[:match]
          search_term = eval options[:term]
        end
      end
    end
    record = load_record search_term, options
    if record.nil?
      Application.info('Metadata') { "Could not find metadata for '#{search_term}'" } if obj.root?
    else
      copy_metadata_from_aleph obj, record
    end
  end
  
  def get_from_disk(obj)
    record = read_record obj
    if record.invalid?
      Application.info('Metadata') { "Could not find metadata in '#{@cfg.metadata_file}'" } if obj.root?
    else
      copy_metadata_as_is obj, record
    end
  end
  
  def load_record(search_term, options)
      search = SearchFactory.new(options[:target]).new_search
      search.query(search_term, options[:index], options[:base], options)
      search.next_record
  end
  
  def read_record(obj)
    doc = XmlDocument.new
    search_term = [obj.label]
    search_term << obj.relative_path.to_s if obj.file_name
    search_term.reverse.each do |term|
      if (dc_file = @metadata_map[term])
        if @cfg.manifestation_format != :DC
          record = RecordFactory.load dc_file
          if record
            record = record.first if record.is_a?(Array) and record.size >= 1
            doc = record.first.to_dc
          end
        else
          doc = XmlDocument.open dc_file
        end
        break
      end
    end
    doc
  end
  
  def save(obj, record, options = {})
    #### :dir ??
    File.open("#{options[:dir]}/#{obj.label}.xml", 'w:utf-8') do |f|
      f.write(record.to_dc)
    end
    
    File.open("#{options[:dir]}/#{obj.label}.raw", 'w:utf-8') do |f|
      f.write(record.to_raw)
    end
  end
  
  def copy_metadata_from_aleph(obj, record)
    begin
      obj.metadata = "#{@cfg.ingest_dir}/transform/dc_#{obj.id}.xml"
      record_doc = record.to_dc(obj.label)
      obj.get_run.get_metadata_fields.each do |tag,value|
        record_doc.root << doc.create_text_node(tag,value)
      end
      record_doc.save(obj.metadata)
    rescue Exception => e
      obj.metadata = nil
      handle_exception e
    end
  end

  def copy_metadata_as_is(obj, record)
    begin
      obj.metadata = "#{@cfg.ingest_dir}/transform/dc_#{obj.id}.xml"
      doc = XmlDocument.new
      records = doc.create_node('records')
      records << record.root
      obj.get_run.get_metadata_fields.each do |tag,value|
        records << doc.create_text_node(tag,value)
      end
      doc.root = records
      doc.save(obj.metadata)
    rescue Exception => e
      obj.metadata = nil
      handle_exception e
    end
  end
  
end
