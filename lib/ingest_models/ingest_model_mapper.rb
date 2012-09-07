# coding: utf-8

require 'json'

require 'tools/exceptions'

require_relative 'ingest_model_factory'

class IngestModelMappper
  
  def initialize( ingestmodel_file )
    @ingestmodel_map = JSON File.open(ingestmodel_file, 'r:utf-8').readlines.join
  end

  def name
    'Ingest Model mapper'
  end

  def get_ingest_model(obj)
    obj = obj.get_master
    src_path = obj.file_path.to_s
    ingest_model_name = @ingestmodel_map[src_path]
    return nil unless ingest_model_name
    ingest_model = IngestModelFactory.instance.get_model1(ingest_model_name)
    return nil unless ingest_model
    ingest_model.get_ingest_model(obj)
  end

end
