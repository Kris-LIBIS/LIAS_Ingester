require_relative 'ingest_model'
require_relative 'model_factory'
require 'pathname'
require 'json'

class IngestModelDispatcher < IngestModel
  
  def initialize( ingestmodel_file, base_dir )
    @base_path = Pathname.new(File.expand_path(base_dir))
    @ingestmodel_map = JSON File.open(ingestmodel_file, 'r:utf-8').readlines.join
  end
  
  def get_manifestation(manifestation, media_type)
    @@logger.error(self.class) { 'Method \'get_manifestation\' not supported here.' }
    return nil
  end
  
  protected
  
  def make_manifestation(src_file_path, src_mime_type, manifestation, tgt_dir, tgt_file_name)
    
    src_path = Pathname.new(src_file_path).relative_path_from(@base_path)
    
    return nil unless ingest_model = @ingestmodel_map[src_path.to_s]
    return nil unless ingest_model = ModelFactory.instance.get_model1(ingest_model)
    
    return ingest_model.make_manifestation( src_file_path, src_mime_type, manifestation, tgt_dir, tgt_file_name )
    
  end
  
end