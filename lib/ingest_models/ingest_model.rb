# coding: utf-8

require 'fileutils'

require 'application_status'
require 'ingester_task'
require 'converters/converter_repository'
require 'converters/type_database'
require 'tools/hash'
require 'tools/mime_type'
require 'converters/type_database'

class IngestModel

  include IngesterTask

  #noinspection RubyResolve
  attr_reader :config
  attr_writer :custom_config
  
  def initialize(config)
    @config = config
    @config.key_strings_to_symbols! :upcase => true, :recursive => true
    debug "Creating ingest model: #{config}"
    @custom_config = nil
  end

  def custom_config(config)
    return self if config.nil? or config.empty?
    result = self.dup
    result.custom_config = config
    result
  end

  def get_ingest_model(obj)
    mime_type = obj.mime_type
    return nil unless mime_type
    get_ingest_model_by_media_type TypeDatabase.instance.mime2media(mime_type)
  end

  def get_ingest_model_by_media_type(media_type)
    return (@config[:MEDIA] == media_type ? self : nil) unless @config[:MEDIA] == :ANY
    ModelFactory.instance.get_model2( media_type, @config[:QUALITY] ).custom_config(@custom_config)
  end


  def valid_media_type(media_type)
    @config[:MEDIA] == :ANY or @config[:MEDIA] == media_type.to_s.upcase.to_sym
  end
  
  def get_manifestation(manifestation, media_type)
    model = get_ingest_model_by_media_type media_type

    model.config[:MANIFESTATIONS].each do |m|
      return m if m[:MANIFESTATION] == manifestation
    end
    
    nil
  end

  def create_manifestation(obj, manifestation)

    if obj.parent? and obj.file_info.nil? # complex object - we create a thumbnail from the first child object
      return nil unless manifestation == 'THUMBNAIL'
      obj = obj.children[0]
      while obj && obj.file_info.nil? && obj.parent?
        obj = obj.children[0]
      end
      return nil unless obj && obj.file_info
    end
    
    tgt_file_name = File.basename( obj.stream_name, '.*' )

    #noinspection RubyResolve
    src_file_path = obj.file_stream ? obj.file_stream : obj.absolute_path
    src_mime_type = obj.mime_type
    
    return nil unless src_file_path and src_mime_type
    
    make_manifestation(src_file_path.to_s, src_mime_type, manifestation, tgt_file_name, obj)
    
  end
  
  protected

  #noinspection RubyResolve
  def make_manifestation(src_file_path, src_mime_type, manifestation, tgt_file_name, obj)

    cfg = obj.get_config
    tgt_dir = "#{cfg.ingest_dir}/transform/streams/"
    accessright = cfg.get_accessright(manifestation, obj)
    watermark_file = "#{cfg.ingest_dir}/watermark_#{manifestation}"

    target = tgt_dir + (tgt_file_name.nil? ? File.basename(src_file_path, '.*') : tgt_file_name)
    
    src_type = TypeDatabase.mime2type src_mime_type

    m = get_manifestation(manifestation, TypeDatabase.type2media(src_type))

    if m.nil?
      warn "Skipping manifestation '#{manifestation}'. Could not find the manifestation in the ingest model."
      return nil
    end

    debug "Using ingestmodel: #{self.inspect}"
    target += ModelFactory.filename_extension(manifestation) + '.' + TypeDatabase.instance.type2ext(m[:FORMAT])

    conversion_operations = m[:OPTIONS] || {}

    if @custom_config
      debug "Has custom config!"
      cfg = @custom_config.detect { |c| c[:MANIFESTATION].upcase == manifestation }
      unless cfg.nil?
        debug "Found config: #{cfg}"
        if cfg[:FILE]
          file_path = File.dirname obj.relative_path
          #noinspection RubyUnusedLocalVariable
          file_name = obj.base_name
          #noinspection RubyUnusedLocalVariable
          file_ext = File.extname file_path
          #noinspection RubyUnusedLocalVariable
          file_dir = File.dirname file_path
          file = File.join(ApplicationStatus.instance.run.location, eval(cfg[:FILE]))
          debug "Looking for file '#{file}'"
          if File.exist?(file)
            conversion_operations = {}
            src_file_path = File.expand_path(file)
            debug "Using source file #{src_file_path}"
            unless cfg[:OPTIONS]
              FileUtils.mkdir_p tgt_dir
              FileUtils.cp src_file_path, target
              info "Copying pregenerated manifestation file '#{file}' to '#{target}'."
              return target
            end
            info "Using pregenerated manifestation file '#{file}."
            src_mime_type = MimeType.get src_file_path
            src_type = TypeDatabase.mime2type src_mime_type
          else
            warn "Pregenerated manifestation file '#{file}' does not exist."
          end
        end
        conversion_operations = conversion_operations.recursive_merge(cfg[:OPTIONS]) if cfg[:OPTIONS]
      end
    end

    if accessright and accessright.is_watermark?
      conversion_operations[:WATERMARK] = { :watermark_info =>accessright.get_watermark, :watermark_file => watermark_file }
    end

    if src_type == m[:FORMAT] && conversion_operations.empty?
      debug  "Skipping manifestation. Target is identical to source."
      return nil
    end

    converter_chain = ConverterRepository.get_converter_chain src_type, m[:FORMAT], conversion_operations

    unless converter_chain
      warn "Skipping manifestation. No suitable converter chain found."
      return nil
    end

    converter_chain.convert src_file_path, target, conversion_operations
    
    target

  end
  
end
