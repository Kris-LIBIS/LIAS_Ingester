require 'fileutils'

require 'ingester_task'
require 'converters/converter_repository'
require 'converters/type_database'

class IngestModel

  include IngesterTask
  
  attr_reader :config
  
  def initialize(config)
    @config = config
    @@logger.debug(self.class) {"Creating ingest model: #{config}"}
    
  end
  
  def get_manifestation(manifestation, media_type)
    puts "Manifestation: #{manifestation}"
    puts "Media type: #{media_type}"
    if @config[:MEDIA] == :ANY and media_type
      model = ModelFactory.instance.get_model2( media_type, @config[:QUALITY] )
      return ( model.get_manifestation manifestation, nil )
    end
    
    @config[:MANIFESTATIONS].each do |m|
      return m if m[:MANIFESTATION] == manifestation
    end
    
    nil
  end
  
  def create_manifestation(obj, manifestation, workdir, protection, watermark_file)
    
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
    
    make_manifestation(src_file_path.to_s, src_mime_type, manifestation, workdir, tgt_file_name,
                       protection, "#{watermark_file}#{manifestation}")
    
  end
  
  protected
  
  def make_manifestation(src_file_path, src_mime_type, manifestation, tgt_dir, tgt_file_name, protection, watermark_file)
    
    target = tgt_dir + (tgt_file_name.nil? ? File.basename(src_file_path, '.*') : tgt_file_name)
    
    src_type = TypeDatabase.mime2type src_mime_type
    media_type = TypeDatabase.type2media src_type

    m = get_manifestation(manifestation, media_type)

    if m.nil?
      warn "Skipping manifestation. No manifestation-config object found."
      return nil
    end

    conversion_operations = m[:OPTIONS] || {}
    if protection and protection.ptype == :WATERMARK
      conversion_operations[:WATERMARK] = { :watermark_info =>protection.pinfo, :watermark_file => watermark_file }
    end

    if (src_type == m[:FORMAT] && conversion_operations.empty?)
      debug  "Skipping manifestation. Target is identical to source."
      return nil
    end

    converter_chain = ConverterRepository.get_converter_chain src_type, m[:FORMAT], conversion_operations

    unless converter_chain
      warn "Skipping manifestation. No suitable converter chain found."
      return nil
    end

    target += ModelFactory.filename_extension(manifestation) + '.' + TypeDatabase.instance.type2ext(m[:FORMAT])

    converter_chain.convert src_file_path, target, conversion_operations
    
    target

  end
  
end
