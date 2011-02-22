require_relative 'converter'

class ArchiveConverter < Converter
  
  protected

  def init(source)
    load_config Application.dir + '/config/converters/archive_converter.yaml'
  end

  def do_convert(target, format)
  end

end
