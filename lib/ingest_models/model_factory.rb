require 'singleton'
require 'yaml'

require_relative 'ingest_model'
require_relative 'ingest_model_dispatcher'

class ModelFactory
  include Singleton

  private

  attr_accessor :models

  MANIFESTATIONS = [ 'ORIGINAL', 'VIEW_MAIN', 'ARCHIVE', 'VIEW', 'THUMBNAIL' ]

  public

  def ModelFactory.generated_manifestations
    return MANIFESTATIONS.slice(1..-1)
  end

  def ModelFactory.all_manifestations
    return MANIFESTATIONS
  end

  def ModelFactory.filename_extension(manifestation)
    return '' if manifestation == 'ORIGINAL'
    return "_#{manifestation}"
  end

  def initialize
    @models = {}
    Dir.glob("#{Application.dir}/config/ingest_models/*.yaml").each do |m|
      @@logger.debug(self.class) {"Loading ingest model: #{m}"}
      f = File.open(m)
      #noinspection RubyResolve
      model = YAML.load(f)
      @models[model[:NAME].downcase] = model
      f.close
    end
  end

  def get_model1(description)
    IngestModel.new @models[description.downcase]
  end

  def get_model2(media, quality)
    @models.each do |_, m|
      if m[:MEDIA] == media and m[:QUALITY] == quality
        return IngestModel.new(m)
      end
    end
    nil
  end

  def get_model_for_config(config)
    return IngestModelDispatcher.new(config.ingest_model_map, config.ingest_run.location) if config.ingest_model_map
    return get_model1(config.ingest_model) if config.ingest_model
    get_model2(config.media_type, config.quality)
  end

end

