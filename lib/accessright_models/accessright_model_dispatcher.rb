# coding: utf-8

require 'pathname'
require 'json'

require 'ingester_task'
require 'tools/exceptions'
require 'models/accessright'
require 'models/accessright_model'

require_relative 'accessright_model_mapper'
require_relative 'accessright_model_factory'

class AccessrightModelDispatcher
  include IngesterTask

  def initialize( id, ar_model_file, ar_model_name, custom_data )
    @id = id
    set_model_map ar_model_file
    set_model_name ar_model_name
    set_model_data custom_data
  end

  def set_model_map(model_file)
    @ar_model_mapper = AccessrightModelMappper.new model_file if model_file
  end

  # !! overwrites custom data !!
  # Order of calling set_model_name and set_model_data is significant
  def set_model_name(model_name)
    @ar_model = AccessrightModelFactory.instance.get_model model_name if model_name
  end

  def set_model_data(ar_model_data)
    model_name = 'custom_' + @id
    @ar_model ||= AccessrightModel.first(name: model_name)
    return if @ar_model && @ar_model.name == model_name
    if @ar_model
      @ar_model = @ar_model.duplicate(model_name)
    else
      @ar_model = AccessrightModel.new(name: model_name)
    end
    ar_model_data.each do |manifestation, value|
      ar = Accessright.from_value(value)
      ar.save
      #noinspection RubyResolve
      @ar_model.set_accessright manifestation, ar
    end
    #noinspection RubyResolve
    @ar_model.save
  end

  def get_accessright_model(obj)

    obj = obj.get_master if obj

    ar_model = @ar_model

    if obj && @ar_model_mapper
      1.times do
        mapped_model = nil
        begin
          mapped_model = @ar_model_mapper.get_model(obj)
        rescue ObjectNotMapped
          warn "Object ##{obj.id} not found in accessright model map."
          break
        end
        if mapped_model
          debug("Found accessright model '#{mapped_model.name}' based on map file lookup.")
          ar_model = mapped_model
        else
          msg = "Accessright model specified in accessright map for object #'#{obj.id}' cannot be found"
          if ar_model.nil?
            error msg + ' and no fall-back accessright model specified.'
          else
            warn msg + '; using fall-back accessright model.'
          end
        end
      end
    end

    ar_model

  end

end
