# coding: utf-8

require 'pathname'
require 'json'

require_relative 'ingest_model'

class IngestModelDispatcher < IngestModel
  
  def initialize( ingestmodel_file, base_dir, custom_config )
    @base_path = Pathname.new(File.expand_path(base_dir))
    @ingestmodel_map = JSON File.open(ingestmodel_file, 'r:utf-8').readlines.join
    @custom_config = custom_config
  end
  
  def get_manifestation(manifestation, media_type)
    #noinspection RubyClassVariableUsageInspection
    @@logger.error(self.class) { 'Method \'get_manifestation\' not supported here.' }
    nil
  end

  def get_ingest_model(obj)
    src_path = obj.file_path.to_s
    ingest_model = @ingestmodel_map[src_path]
    ingest_model = ModelFactory.instance.get_model1(ingest_model)
    ingest_model.custom_config @custom_config
  end
  
  protected
  
  def make_manifestation(src_file_path, src_mime_type, manifestation, tgt_file_name, obj)
    
    ingest_model = get_ingest_model(obj)
    ingest_model.make_manifestation( src_file_path, src_mime_type, manifestation, tgt_file_name, obj )
    
  end
  
end