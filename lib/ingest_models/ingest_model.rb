require 'fileutils'

Dir.glob(File.dirname(__FILE__) + '/../converters/*.rb').each do |f|
  require "#{f}"
end

class IngestModel

  attr_reader :config

  def initialize(config)
    @config = config
  end

  def get_manifestation(manifestation)
    @config[:MANIFESTATIONS].each do |m|
      return m if m[:MANIFESTATION] == manifestation
    end
    return nil
  end

  def create_manifestation(obj, manifestation, workdir)

    return unless obj.file_info # this prohibits this method for complex objects

    file_path = obj.file_path
    target = workdir + File.basename( file_path, '.*' )

    m = get_manifestation(manifestation)
    converter = get_converter file_path

    return nil if m.nil? or (converter.type2mime(m[:FORMAT]) == obj.mime_type && m[:OPTIONS].nil?)

    target += ModelFactory.filename_extension(manifestation) + '.' + converter.type2ext(m[:FORMAT])

    if m[:OPTIONS]
      m[:OPTIONS].each do |k,v|
        converter.resize v if k == :RESIZE
        converter.scale v if k == :SCALE
        converter.quality v if k == :QUALITY
      end
    end

    converter.convert(target, m[:FORMAT])

    return target

  end

  def get_converter(file)
    case @config[:MEDIA]
    when :IMAGE
      return ImageConverter.new(file)
    when :AUDIO
      return AudioConverter.new(file)
    when :VIDEO
      return VideoConverter.new(file)
    when :DOCUMENT
      return DocumentConverter.new(file)
    when :ARCHIVE
      return ArchiveConverter.new(file)
    end
    return nil
  end

end
