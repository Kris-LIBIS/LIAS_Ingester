require 'lib/application_task'
require 'lib/libis/record'
require 'lib/libis/search'
require 'json'

class Metadata
  include ApplicationTask
  
  SearchOptions = {:host => 'http://opac.libis.be/X', :target => 'Opac', :base => 'KADOC', :index => 'sig'}
  
  def initialize(cfg)
    raise StandardError.new("input #{cfg} is not an IngestConfig") unless cfg.is_a?(IngestConfig)
    @cfg = cfg
    
    @metadata_map = {}
    if mf = @cfg.metadata_file
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
    options = SearchOptions.merge @cfg.get_search_options
    search_term = obj.label
    if options[:term]
      if (options[:match])
        search_term = obj.file_name if obj.file_name
        if (search_term =~ options[:match])
          search_term = eval options[:term]
        end
      end
    end
    record = load_record search_term, options
    if record.nil?
      Application.warn('Metadata') { "Could not find metadata for '#{search_term}'" } if obj.root?
    else
      copy_metadata_from_aleph obj, record
    end
  end
  
  def get_from_disk(obj)
    record = read_record obj
    if record.nil? or record.empty?
      Application.warn('Metadata') { "Could not find metadata in '#{metadata_file}'" } if obj.root?
    else
      copy_metadata_as_is obj, record
    end
  end
  
  def load_record(search_term, options)
      search = SearchFactory.new(options[:target]).new_search
      search.query(search_term, options[:index], options[:base], options)
      found = nil
      i = 0
      search.each do |r|
        record = Record.new(r)
        # is this required?
        # save(obj, record, :file_name => "#{search_term}_#{i}")
        found = record unless found
      end
      
      return found
  end
  
  def read_record(obj)
    search_term = [obj.label]
    search_term << obj.relative_path.to_s if obj.file_name
    search_term.reverse.each do |term|
      if dc_file = @metadata_map[term]
        return File.open(dc_file, 'r:utf-8').readlines.join
      end
    end
    return nil
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
    obj.metadata = "#{@cfg.ingest_dir}/transform/dc_#{obj.id}.xml"
    File.open(obj.metadata, "w:utf-8") do |f|
      f.puts "<records>"
      f.puts record.to_dc(obj.label)
      f.puts "</records>"
    end
  end
  
  def copy_metadata_as_is(obj, record)
    obj.metadata = "#{@cfg.ingest_dir}/transform/dc_#{obj.id}.xml"
    begin
      File.open(obj.metadata, "w:utf-8") do |f|
        f.puts "<records>"
        f.puts record.to_s
        f.puts "</records>"
      end
    rescue Exception => e
      obj.metadata = nil
      handle_exception e
    end
  end
  
end
