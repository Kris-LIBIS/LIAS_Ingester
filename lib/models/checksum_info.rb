class ChecksumInfo
  include DataMapper::Resource

  property    :id,            Serial
  property    :checksum_type, Enum[:MD5, :SHA1, :SHA256, :SHA384, :SHA512]
  property    :checksum,      String

  belongs_to  :file_info

  def initialize(file_path, checksum_type)
    self.checksum_type = checksum_type
    recalculate file_path
  end

  def recalculate(file_path)
    self.checksum = Checksum.new(self.checksum_type).get(file_path)
  end

  def debug_info(indent = 0)
    p ' ' * indent + self.inspect
  end

end
