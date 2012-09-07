# coding: utf-8

require 'singleton'
require 'yaml'

require_relative 'ingest_model'
require_relative 'ingest_model_dispatcher'

class IngestModelFactory
  include Singleton

  private

  #noinspection RubyResolve
  attr_accessor :models

  public

  def self.filename_extension(manifestation)
    return '' if manifestation == 'ORIGINAL'
    return "_#{manifestation}"
  end

  def initialize
    load_models("#{Application.dir}/config/ingest_models")
  end

  def get_model1(description)
    @models[description.downcase]
  end

  def get_model2(media, quality)
    @models.each do |_, m|
      if m.config[:MEDIA] == media and m.config[:QUALITY] == quality
        return m
      end
    end
    nil
  end

  def add_model(model, name = nil)
    @models[(name ? name : model.name).downcase] = model
  end

  protected

  def load_models(path)
    @models = {}
    Dir.glob("#{path}/*.yaml").each do |m|
      #noinspection RubyClassVariableUsageInspection
      @@logger.debug(self.class) { "Loading ingest model: #{m}" }
      #noinspection RubyClassVariableUsageInspection
      begin
        File.open(m) do |f|
          #noinspection RubyResolve
          model = IngestModel.new(YAML.load(f))
          add_model model
          model.config[:ALIASES] ||= []
          model.config[:ALIASES].each { |name| add_model model, name }
        end
      rescue Exception => ex
        Application.logger.error(self.class) { "Cannot load ingest model '#{m}': #{ex.message}" }
        raise ex
      end
    end
  end

end

