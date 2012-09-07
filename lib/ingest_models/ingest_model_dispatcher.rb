# coding: utf-8

require 'pathname'
require 'json'

require_relative 'ingest_model_factory'
require_relative 'ingest_model_mapper'


class IngestModelDispatcher
  
  def initialize( id, ingestmodel_file, ingest_model_name, media_type, quality, custom_config )
    @id = id
    set_model_map ingestmodel_file
    set_model_name ingest_model_name
    set_model_qualifiers media_type, quality
    @custom_config = custom_config
  end
  
  def get_ingest_model(obj)

    obj = obj.get_master if obj

    if obj && @model_mapper
      if (model = @model_mapper.get_ingest_model obj)
        return model.get_ingest_model(obj).custom_config(@custom_config) if model
        msg = "Ingest model specified in mapping file for object #'#{obj.id}' cannot be found"
        if @model.nil?
          error msg + ' and no fall-back ingest model specified.'
          return nil
        else
          warn msg + '; using fall-back ingest model.'
        end
      end
    end

    return nil unless @model

    @model.custom_config(@custom_config)

  end
  
  protected
  
  def set_model_map(model_file)
    @model_mapper = IngestModelMappper.new model_file if model_file
  end

  def set_model_name(model_name)
    @model = IngestModelFactory.instance.get_model1 model_name if model_name
  end

  def set_model_qualifiers(media_type, quality)
    m = IngestModelFactory.instance.get_model2(media_type, quality)
    @model = m if m
  end

end