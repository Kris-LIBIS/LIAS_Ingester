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
    @quality = 100
    load_config Application.dir + '/config/converters/image_converter.yaml'
  end

  def do_convert(target,format)
    format = :JP2 if format == :JPEG2000
    @work.format = format.to_s if format
    Application.debug('ImageConverter') { "Writing conversion #{@work.inspect}" }
    q = @quality
    if format == :JP2
      @work.format = "BMP"
      tmp_file = target + '.tmp.bmp' if format == :JP2
      @work.write(tmp_file) { self.quality = q; self.filename = tmp_file }
      result = `j2kdriver -i #{tmp_file} -t jp2 -R 0 -w R53 -o #{target} 2>&1`
      if result.match(/error/i)
        Application.error ('ImageConverter') { "JPEG2000 conversion failed: #{result}" }
      elsif result.match(/warning/i)
        Application.warn ('ImageConverter') { "JPEG2000 conversion: #{result}" }
      end
      FileUtils.rm(tmp_file)
    else
      @work.write(target) { self.quality = q; self.filename = target }
    end
  end

end
