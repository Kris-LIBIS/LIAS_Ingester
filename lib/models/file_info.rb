# coding: utf-8

require 'dm-core'

require 'tools/mime_type'

#noinspection RubyResolve
class FileInfo
  include DataMapper::Resource
  
  property    :id,            Serial
  property    :file_path,     FilePath
  property    :mtime,         DateTime, :required => true
  property    :mime_type,     String
  
  has n,      :checksum_infos
  
  belongs_to  :ingest_object
  
  before :destroy do |_|
    self.checksum_infos.destroy
    true
  end
  
  def initialize(file_path, checksum_type = nil)
    self.file_path  = file_path
    self.mtime      = File.mtime file_path
    self.mime_type  = MimeType.get file_path
    self.checksum_infos  << ChecksumInfo.new(file_path, checksum_type) if checksum_type
  end
  
  def file_name
    File.basename self.file_path.to_s
  end
  
  def base_name
    File.basename self.file_path, '.*'
  end
  
  def get_checksum( checksum_type )
    checksum = self.checksum_infos.all(:checksum_type => checksum_type)
    return checksum[0].checksum unless(checksum.empty?)
    self.checksum_infos << (c = ChecksumInfo.new(self.file_path, checksum_type))
    c.checksum
  end
  
  def recalculate_checksums
    self.checksum_infos.each { |c| c.recalculate self.file_path }
  end
  
  def debug_print( indent = 0 )
    p ' ' * indent + self.inspect
    self.checksum_infos.each { |c| c.debug_info indent + 2 }
  end
  
end
