require 'libis/record'
require 'libis/search'

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
      fname = @obj.file_name
      fname =~ @obj.get_config.filename_match
      search_term = eval options[:term]
    end
    record = load_record search_term, final_options
    copy_metadata record
  end

  def get_from_disk(metadata_file)
    record = read_record metadata_file
    copy_metadata record
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
      if fields.first == @obj.file_name
        return File.read(fields[1])
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

  def copy_metadata(record)
    if record
      @obj.metadata = "#{@obj.get_config.ingest_dir}/transform/dc_#{@obj.id}.xml"
      File.open(@obj.metadata, "w") do |f|
        f.puts "<records>"
        f.puts record.to_dc.to_s.gsub(/\s*<\?.*\?>[\n]*/,'')
        f.puts "</records>"
      end
    end
  end

end
