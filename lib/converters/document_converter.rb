require File.dirname(__FILE__) + '/converter'

class DocumentConverter < Converter
  
  protected

  def init(source)
    load_config Application.dir + '/config/converters/document_converter.yaml'
  end

  def do_convert(target, format)
  end

end
