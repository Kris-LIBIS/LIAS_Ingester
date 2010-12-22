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

    src_file_path = obj.file_path
    src_mime_type = obj.mime_type
    tgt_file_name = nil

    if obj.root? and obj.parent? and obj.file_info.nil? # complex object - we create a thumbnail from the first child object
      return unless manifestation == 'THUMBNAIL'
      first_child   = obj.children[0]
      return nil unless first_child
      src_file_path = first_child.file_path
      src_mime_type = first_child.mime_type
      tgt_file_name = obj.label
    end

    return nil unless src_file_path and src_mime_type

    return make_manifestation(src_file_path, src_mime_type, manifestation, workdir, tgt_file_name)

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

  protected

  def make_manifestation(src_file_path, src_mime_type, manifestation, tgt_dir, tgt_file_name)
    
    target = tgt_dir + (tgt_file_name.nil? ? File.basename(src_file_path, '.*') : tgt_file_name)

    m = get_manifestation(manifestation)
    converter = get_converter src_file_path

    return nil if m.nil? or (converter.type2mime(m[:FORMAT]) == src_mime_type && m[:OPTIONS].nil?)

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

end
