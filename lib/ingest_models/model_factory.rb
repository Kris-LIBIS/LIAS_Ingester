require 'singleton'
require 'yaml'
require_relative 'ingest_model'

class ModelFactory
  include Singleton

  private

  attr :models

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
      model = YAML.load(File.open(m))
      @models[model[:NAME].downcase] = model
    end
  end

  def get_model1(description)
    return IngestModel.new(@models[description.downcase])
  end

  def get_model2(media, quality)
    @models.each do |n, m|
      if m[:MEDIA] == media and m[:QUALITY] == quality
        return IngestModel.new(m)
      end
    end
    return nil
  end

  def get_model_for_config(config)
    return get_model1(config.ingest_model) if config.ingest_model
    return get_model2(config.media_type, config.quality)
  end

end

