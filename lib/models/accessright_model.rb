# coding: utf-8

require 'dm-core'

require 'ingester_task'

require_relative 'accessright'

#noinspection RubyResolve
class AccessrightModel
  include DataMapper::Resource
  include IngesterTask

  property    :id,              Serial
  property    :name,            String

  has n,      :accessrights,    through: :ar_model_links
  has n,      :ar_model_links

  has n,      :ingest_object

  before :save, :before_save
  after :save, :after_save

  def before_save
  end

  def after_save
    self.accessrights.save
    self.ar_model_links.save
  end

  def initialize(data)
    debug "Creating new AccessrightModel with data: #{data}"
    data.key_strings_to_symbols! :downcase => true, :recursive => true
    self.name = data[:name]
    data[:manifestations].each do |usage_type, accessright_data|
      accessright = Accessright.from_value accessright_data
      accessright.save
      set_accessright(usage_type, accessright)
    end if data[:manifestations]
  end

  def duplicate(new_name)
    new_model = AccessrightModel.new(name: new_name)
    ar_model_links.each { | link | new_model.set_accessright link.usage_type, link.accessright }
    new_model
  end

  def set_accessright(usage_type, accessright)
    link = self.ar_model_links.first_or_new({usage_type: usage_type}, {accessright_model: self})
    link.accessright = accessright
  end

  def get_accessright(usage_type)
    link = self.ar_model_links.first(usage_type: usage_type)
    return nil unless link
    link.accessright
  end

  def get_accessrights()
    result = {}
    self.ar_model_links.each { |link| result[link.usage_type] = link.accessright }
    result
  end

  def debug_print(indent = 0)
    indent += 1
    get_accessrights.each do |k,v|
      p ' ' * indent + k.to_s + ':' + v.inspect
    end
  end

end