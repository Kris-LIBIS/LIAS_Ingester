# coding: utf-8

require 'json'

require 'tools/exceptions'

require_relative 'accessright_model_factory'

class AccessrightModelMappper
  
  def initialize( ar_model_file )
    @ar_model_map = JSON File.open(ar_model_file, 'r:utf-8').readlines.join
  end

  def name
    'Accessright Model mapper'
  end

  def get_model(obj)
    file_path = obj.get_master.relative_path.to_s
    unless (model_name = @ar_model_map[file_path])
      raise ObjectNotMapped, "File '#{file_path}' not found in the mapping table", caller
    end
    AccessrightModelFactory.instance.get_model(model_name)
  end

end
