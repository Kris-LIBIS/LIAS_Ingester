# coding: utf-8

# This class is able to perform all file checks that we may want to perform during pre-ingest
# - check if the file exists
# - check if the file name matches a given filter
# - check if the file type matches a given mime type filter
# - check the file for viruses
# - check the checksum of the file
# - check if the file was already ingested before

class FileCheckException < StandardError
end

class FileChecker
  
  def initialize(config = nil)
    @raise_exception = false
    @config = config
  end
  
  private
  
  def config_init(obj)
    @config = obj.get_config unless @config
  end
  
  def check_throw(test, obj)
    unless test
      raise FileCheckException, "Object #{obj.id}: #{obj.message}", caller(1) if @raise_exception
    end
    test
  end
  
  public
  
  def match(obj)
    return false unless (check_filename(obj) and check_mimetype(obj))
    true
  end
  
  def check(obj)
    
    config_init obj
    
    return false unless check_exists(obj)
    
    result = \
         (@config.check_virus     ? check_virus(obj)    : true) \
      && (@config.check_checksum  ? check_checksum(obj) : true) \
      && (@config.check_ingested  ? check_ingested(obj) : true)
    
    result
    
  end
  
  def check_exists(obj)
    
    result = File.exists? obj.file_path
    obj.message = "File '#{obj.file_path}' does not exist" unless result
    check_throw result, obj
    
  end
  
  def check_filename(obj)
    
    config_init obj
    
    filter = @config.filename_match
    raise(FileCheckException, "#{filter} is not a regular expression") unless filter.is_a? Regexp
    
    result = (filter.nil? or obj.file_name =~ filter or obj.file_path.to_s =~ filter)
    obj.message = "File '#{obj.file_name}' does not match the filter '#{filter.inspect}'" unless result
    
    check_throw result, obj
    
  end
  
  def check_mimetype(obj)
    
    return false unless check_exists(obj)
    
    config_init obj
    
    filter = @config.mime_type
    raise(FileCheckException, "#{filter} is not a regular expression") unless filter.is_a? Regexp
    
    obj.mime_type = %x(file -ib #{obj.file_path}) if obj.mime_type.nil?
    
    result = (filter.nil? or obj.mime_type =~ filter)
    obj.message = "File's MIME-type '#{obj.mime_type}' does not match the filter '#{filter.inspect}'" unless result
    
    check_throw result, obj
    
  end
  
  def check_virus(obj)
    
    return false unless check_exists(obj)
    
    scanner = VirusScanner.new
    
    result = scanner.check(obj.file_path)
    unless result
      obj.more_info = scanner.more_info
      obj.message   = "Viruschecker reports the file may contain a virus"
    end
    
    check_throw result, obj
    
  end
  
  def check_checksum(obj, checksum_to_check = nil)
    
    return false unless check_exists(obj)
    
    config_init obj
    
    checksum = obj.get_checksum(@config.checksum_type)
    
    result = (checksum == checksum_to_check)
    
    unless checksum_to_check
      raise(FileCheckException, "Checksum_file should be specified in the configuration") if @config.checksum_file.nil?
      checksum_file_path = File.absolute_path(@config.checksum_file, @config.ingest_run.location)
      result = Checksum.check(checksum, obj.file_name, checksum_file_path)
    end
    
    obj.message = "File '#{obj.file_path}' checksum check failed." unless result
    
    check_throw result, obj
    
  end
  
  def check_ingested(obj)
    
    config_init obj
    
    existing_file = IngestObject.first(:status => Status::Done, :file_info => {:file_path => obj.file_path}, :order => [ :updated_at.desc ])
    
    result  = false
    result  = existing_file.file_info.mtime == obj.file_info.mtime if existing_file
    result |= existing_file.get_checksum(@config.checksum_type) == obj.get_checksum(@config.checksum_type) if existing_file
    
    obj.message = "File '#{obj.file_path}' already ingested" if result
    
    result = !result
    
    check_throw result, obj
    
  end
  
end

