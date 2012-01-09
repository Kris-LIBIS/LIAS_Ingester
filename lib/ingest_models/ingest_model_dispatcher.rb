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
    @@logger.error(self.class) { 'Method \'get_manifestation\' not supported here.' }
    nil
  end
  
  protected
  
  def make_manifestation(src_file_path, src_mime_type, manifestation, tgt_dir, tgt_file_name, protection, watermark_file, obj)
    
    src_path = Pathname.new(src_file_path).relative_path_from(@base_path)
    
    return nil unless ingest_model = @ingestmodel_map[src_path.to_s]
    return nil unless ingest_model = ModelFactory.instance.get_model1(ingest_model)

    ingest_model.custom_config @custom_config
    
    ingest_model.make_manifestation( src_file_path, src_mime_type, manifestation, tgt_dir, tgt_file_name, protection, watermark_file, obj )
    
  end
  
end