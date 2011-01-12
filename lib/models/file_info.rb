require 'lib/tools/mime_type'

class FileInfo
  include DataMapper::Resource

  property    :id,            Serial
  property    :file_path,     FilePath
  property    :mtime,         DateTime, :required => true
  property    :mime_type,     String
 
  has n,      :checksum_infos

  belongs_to  :ingest_object

  before :destroy do |post|
    self.checksum_infos.destroy
    true
  end

  def initialize(file_path, checksum_type = nil)
    self.file_path  = file_path
    self.mtime      = File.mtime file_path
    self.mime_type  = MimeType.get file_path
    self.checksum_infos  << ChecksumInfo.new(file_path, checksum_type)
  end

  def file_name
    File.basename self.file_path
  end

  def base_name
    File.basename self.file_path, '.*'
  end

  def get_checksum( checksum_type )
    checksum = self.checksum_infos.all(:checksum_type => checksum_type)
    return checksum[0].checksum unless(checksum.empty?)
    self.checksum_infos << (c = ChecksumInfo.new(self.file_path, checksum_type))
    return c.checksum
  end

  def recalculate_checksums
    checksum_infos.each { |c| c.recalculate self.file_path }
  end

  def debug_info( indent = 0 )
    p ' ' * indent + self.inspect
    checksum_infos.each { |c| c.debug_info indent + 2 }
  end

end
