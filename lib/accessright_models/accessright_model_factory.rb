# coding: utf-8

require 'singleton'
require 'yaml'

require 'ingester_task'
require 'models/accessright_model'

class AccessrightModelFactory
  include Singleton
  include IngesterTask

  private

  attr_accessor :models

  public

  def initialize
    load_models("#{Application.dir}/config/accessright_models")
  end

  def get_model(name)
    @models[name.downcase]
  end

  protected

  def load_models(path)
    @models = {}
    Dir.glob("#{path}/*.yaml").each do |m|
      debug "Loading accessright model: #{m}"
      File.open(m) do |f|
        #noinspection RubyResolve
        model = YAML.load(f)
        model.key_strings_to_symbols! :downcase => true, :recursive => true
        name = model[:name]
        ar_model = AccessrightModel.first(:name => name)
        ar_model ||= AccessrightModel.new(model)
        @models[name.downcase] = ar_model
        model[:aliases] ||= []
        model[:aliases].each { name | @models[name.downcase] = ar_model }
      end #rescue error "Cannot load acessright model '#{m}'"
    end
  end

end