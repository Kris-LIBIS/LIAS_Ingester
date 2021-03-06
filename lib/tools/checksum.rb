# coding: utf-8

#noinspection RubyResolve
require 'digest/md5'
#noinspection RubyResolve
require 'digest/sha1'
require 'digest/sha2'

require 'tools/exceptions'

class Checksum
  CHECKSUM_TYPES = [:MD5, :SHA1, :SHA256, :SHA384, :SHA512]
  CHECKSUM_TYPES_STRING = %w(MD5 SHA1 SHA256 SHA384 SHA512)

  BUF_SIZE = 10240
  attr :type, :hasher

  def initialize(type)
    raise AbortException, "Checksum: bad checksum type: '#{type}' - should be one of #{CHECKSUM_TYPES.inspect}" unless CHECKSUM_TYPES.include? type
    @type   = type
    @hasher = case type
             when :MD5
               ::Digest::MD5.new()
             when :SHA1
               ::Digest::SHA1.new
             when :SHA256
               ::Digest::SHA2.new(256)
             when :SHA384
               ::Digest::SHA2.new(384)
             when :SHA512
               ::Digest::SHA2.new(512)
             end
  end

  def self.type_from_string(type_string)
    raise StandardError, "Checksum: bad checksum type: '#{type_string}' - should be one of #{CHECKSUM_TYPES_STRING.inspect}" unless CHECKSUM_TYPES_STRING.include? type_string.upcase
    return CHECKSUM_TYPES[CHECKSUM_TYPES_STRING.index(type_string.upcase)]
  end

  def self.type_to_string(type)
    raise AbortException, "Checksum: bad checksum type: '#{type}' - should be one of #{CHECKSUM_TYPES.inspect}" unless CHECKSUM_TYPES.include? type
    return CHECKSUM_TYPES_STRING[CHECKSUM_TYPES.index(type)]
  end

  def get(file_path)

    if File.exists? file_path

      File.open(file_path, 'r') do |fh|
        while buffer = fh.read(BUF_SIZE)
          @hasher << buffer
        end
      end

      return @hasher.hexdigest

    end

    nil

  end

  def self.check(file_checksum, file_name, checksumfile_path)

    if File.exists? checksumfile_path
      checksum_line = %x(grep #{file_name} #{checksumfile_path})
      # we'll try to match any field on the line as the file format differs between platforms
      checksum_line.split.each do |l|
        return true if l == file_checksum
      end
    end

    return false

  end

  def check_file(file_path, checksumfile_path)
    file_checksum = get(file_path)
    file_name = File.basename(file_path)
    check(file_checksum, file_name, checksumfile_path)
  end

end
