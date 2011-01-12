require 'lib/libis/record'
require 'lib/libis/search'

class Metadata
  
  SearchOptions = {:host => 'http://opac.libis.be/X', :target => 'Opac', :base => 'KADOC', :index => 'sig'}
  
  def initialize(obj)
    raise StandardError.new("input #{obj} is not an IngestObject") unless obj.is_a?(IngestObject)
    @obj = obj
  end
  
  def get_from_aleph(options)
    final_options = SearchOptions.merge options
    search_term = @obj.label
    if options[:term]
      if (options[:match])
        search_term = @obj.file_name if @obj.file_name
        if (search_term =~ options[:match])
          search_term = eval options[:term]
        end
      end
    end
    record = load_record search_term, final_options
    if record.nil?
      Application.warn('Metadata') { "Could not find metadata for '#{search_term}'" }
    else
      copy_metadata_from_aleph record
    end
  end
  
  def get_from_disk(metadata_file)
    record = read_record metadata_file
    if record.nil? or record.empty?
      Application.warn('Metadata') { "Could not find metadata in '#{metadata_file}'" }
    else
      copy_metadata_as_is record
    end
  end
  
  private
  
  def load_record(search_term, options)
      search = SearchFactory.new(options[:target]).new_search
      search.query(search_term, options[:index], options[:base], options)
      found = nil
      i = 0
      search.each do |r|
        record = Record.new(r)
        # is this required?
        # save(record, :file_name => "#{search_term}_#{i}")
        found = record unless found
      end
      
      return found
  end
  
  def read_record(metadata_file)
    File.open(metadata_file, 'r').each_line do |line|
      fields = line.split
      if fields.first =~ /(.*\/)?#{@obj.file_name}/
        return File.open(fields.last, 'r:utf-8').readlines.join
      end
    end
    return nil
  end
  
  def save(record, options = {})
    #### :dir ??
    File.open("#{options[:dir]}/#{@obj.label}.xml", 'w') do |f|
      f.write(record.to_dc)
    end
    
    File.open("#{options[:dir]}/#{@obj.label}.raw", 'w') do |f|
      f.write(record.to_raw)
    end
  end
  
  def copy_metadata_from_aleph(record)
    @obj.metadata = "#{@obj.get_config.ingest_dir}/transform/dc_#{@obj.id}.xml"
    File.open(@obj.metadata, "w") do |f|
      f.puts "<records>"
      f.puts record.to_dc(@obj.label).to_s.gsub(/\s*<\?.*\?>[\n]*/,'')
      f.puts "</records>"
    end
  end
  
  def copy_metadata_as_is(record)
    @obj.metadata = "#{@obj.get_config.ingest_dir}/transform/dc_#{@obj.id}.xml"
    begin
      File.open(@obj.metadata, "w") do |f|
        f.puts "<records>"
        f.puts record.to_s.gsub(/\s*<\?.*\?>[\n]*/,'')
        f.puts "</records>"
      end
    rescue Exception => e
      @obj.metadata = nil
      handle_exception e
    end
  end
  
end
