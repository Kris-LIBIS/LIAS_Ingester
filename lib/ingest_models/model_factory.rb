# coding: utf-8

require 'singleton'
require 'yaml'

require_relative 'ingest_model'
require_relative 'ingest_model_dispatcher'

class ModelFactory
  include Singleton

  private

  #noinspection RubyResolve
  attr_accessor :models

  #noinspection RubyConstant
  MANIFESTATIONS = %w(ORIGINAL VIEW_MAIN ARCHIVE VIEW THUMBNAIL)

  public

  def self.manifestations
    return MANIFESTATIONS.slice(1..-1)
  end

  def self.all_manifestations
    return MANIFESTATIONS
  end

  def self.filename_extension(manifestation)
    return '' if manifestation == 'ORIGINAL'
    return "_#{manifestation}"
  end

  def initialize
    @models = {}
    Dir.glob("#{Application.dir}/config/ingest_models/*.yaml").each do |m|
      #noinspection RubyClassVariableUsageInspection
      @@logger.debug(self.class) {"Loading ingest model: #{m}"}
      #noinspection RubyClassVariableUsageInspection
      File.open(m) do |f|
        #noinspection RubyResolve
        model = YAML.load(f)
        @models[model[:NAME].downcase] = model
        model[:ALIASES] ||= []
        model[:ALIASES].each { name | @models[name.downcase] = model }
      end rescue @@logger.error(self.class) {"Cannot load ingest model '#{m}'"}
    end
  end

  def get_model_for_config(config)
    #noinspection RubyResolve
    return IngestModelDispatcher.new(config.ingest_model_map, config.ingest_run.location, config.manifestations_config) if config.ingest_model_map
    return get_model1(config.ingest_model).custom_config(config.manifestations_config) if config.ingest_model
    #noinspection RubyResolve
    get_model2(config.media_type, config.quality).custom_config(config.manifestations_config)
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

end

