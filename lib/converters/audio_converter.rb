require_relative 'converter'

class AudioConverter < Converter
  
  protected

  def init(source)
    load_config Application.dir + '/config/converters/audio_converter.yaml'
  end

  def do_convert(target, format)
  end

end
