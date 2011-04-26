require 'fileutils'

Dir.glob('../converters/*.rb').each do |f|
  require_relative f
end

class IngestModel
  
  attr_reader :config
  
  def initialize(config)
    @config = config
    @@logger.debug(self.class) {"Creating ingest model: #{config}"}
    
  end
  
  def get_manifestation(manifestation, media_type)
    
    if @config[:MEDIA] == :ANY and media_type
      model = ModelFactory.instance.get_model2( media_type, @config[:QUALITY] )
      return ( model.get_manifestation manifestation, nil )
    end
    
    @config[:MANIFESTATIONS].each do |m|
      return m if m[:MANIFESTATION] == manifestation
    end
    
    nil
  end
  
  def create_manifestation(obj, manifestation, workdir)
    
    tgt_file_name = obj.label
    
    if obj.parent? and obj.file_info.nil? # complex object - we create a thumbnail from the first child object
      return nil unless manifestation == 'THUMBNAIL'
      p = obj
      while p = p.parent
        tgt_file_name = p.label + '_' + tgt_file_name
      end
      obj = obj.children[0]
      while obj && obj.file_info.nil? && obj.parent?
        obj = obj.children[0]
      end
      return nil unless obj && obj.file_info
    else
#      tgt_file_name = obj.relative_path.dirname + obj.relative_path.basename('.*')
      tgt_file_name = File.basename( obj.flattened_relative, '.*' )
    end
    
    src_file_path = obj.file_stream ? obj.file_stream : obj.absolute_path
    src_mime_type = obj.mime_type
    
    return nil unless src_file_path and src_mime_type
    
    make_manifestation(src_file_path.to_s, src_mime_type, manifestation, workdir, tgt_file_name)
    
  end
  
  def get_converter(file)
    
    case @config[:MEDIA]
    when :ANY
      mime_type = MimeType.get(file)
      converter = Converter.get_converters.detect { |c| c.new(file).support_mimetype? mime_type }
      return converter.new(file) if converter
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
    nil
  end
  
  protected
  
  def make_manifestation(src_file_path, src_mime_type, manifestation, tgt_dir, tgt_file_name)
    
    target = tgt_dir + (tgt_file_name.nil? ? File.basename(src_file_path, '.*') : tgt_file_name)
    
    converter = get_converter src_file_path
    return nil unless converter && converter.initialized?
    
    m = get_manifestation(manifestation, converter.media_type)
    
    return nil if m.nil? or (converter.type2mime(m[:FORMAT]) == src_mime_type && m[:OPTIONS].nil?)
    
    target += ModelFactory.filename_extension(manifestation) + '.' + converter.type2ext(m[:FORMAT])
    
    if m[:OPTIONS]
      m[:OPTIONS].each do |k,v|
        converter.resize v if k == :RESIZE
        converter.scale v if k == :SCALE
        converter.quality v if k == :QUALITY
      end
    end
    
    FileUtils.mkdir_p File.dirname(target)
    
    converter.convert(target, m[:FORMAT])
    
    target
    
  end
  
end
