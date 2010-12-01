require 'rubygems'
require 'RMagick'
require 'converters/converter'

class ImageConverter
  include Converter

  attr_reader :source, :work
  attr :quality

  def scale(percent)
    @work.scale!(percent/100.0)
  end

  def resize(geometry)
    @work.resize_to_fit!(geometry)
  end

  def quality(value)
    @quality = value
  end

  def watermark(text)
    watermark = Magick::Image.new @work.columns / 3, @work.rows/4
    
    gc = Magick::Draw.new
    gc.gravity = Magick::CenterGravity
    gc.pointsize = @work.columns / 50
    gc.font_family = "Helvetica"
    gc.font_weight = Magick::BoldWeight
    gc.stroke = 'none'
    gc.rotate -20
    gc.text 0, 0, (text or text == '' ? text : 'LIBIS')
    
    gc.draw watermark
    
    watermark = watermark.shade true, 310, 30
    
    @work.composite_tiled!(watermark, Magick::HardLightCompositeOp)

  end

  protected

  def init(source)
    @source = Magick::Image.read(source).first
    @work   = @source.clone
    @quality = 90
    load_config Application.dir + '/config/converters/image_converter.yaml'
  end

  def do_convert(target,format)
    format = :JP2 if format == :JPEG2000
    @work.format = format.to_s if format
    Application.info('ImageConverter') { "Writing conversion #{@work.inspect}" }
    q = @quality
    @work.write(target) { self.quality = q; self.filename = target }
  end

end
