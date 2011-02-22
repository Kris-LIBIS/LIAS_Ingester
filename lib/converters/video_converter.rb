require_relative 'converter'

class VideoConverter < Converter
  
  protected

  def init(source)
    load_config Application.dir + '/config/converters/video_converter.yaml'
  end

  def do_convert(target, format)
  end

end
