require 'rubygems'
require 'quick_magick'
require 'RMagick'
require File.dirname(__FILE__) + '/converter'

class ImageConverter
  include Converter

  attr_reader :work

  def scale(percent)
    @work.append_to_settings('scale', percent)
  end

  def resize(geometry)
    @work.append_to_settings('resize',geometry)
  end

  def quality(value)
    @work.append_to_settings('quality', value)
  end

  def get_watermark_file(dir, usage_type)
    file = "#{dir}/watermark_#{usage_type}.png"
  end

  def create_watermark(text, dir, usage_type)
 
    file = get_watermark_file(dir, usage_type)
    return file if File.exist?(file)

    watermark = Magick::Image.new(1000, 1000) { self.background_color = 'transparent' }

    
    gc = Magick::Draw.new
    gc.fill = 'black'
    gc.stroke = 'black'
    gc.gravity = Magick::CenterGravity
    gc.pointsize = 100
    gc.font_family = "Helvetica"
    gc.font_weight = Magick::BoldWeight
    gc.stroke = 'none'
    gc.rotate -20
    gc.text 0, 0, (text.nil? ? ' (C) LIBIS' : text)
    
    gc.draw watermark
    
#    watermark = watermark.shade true, 310, 30
    watermark = watermark.blur_image 2.0, 1.0

    watermark.write('png:' + file)

    file

  end

  def watermark(source, target, watermark_image)

    `#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_bin_dir']}/run_watermarker2.sh #{source} #{target} #{watermark_image} X2`
    return
    watermark = Magick::Image.read(watermark_image).first
    watermark = watermark.transparent('white',Magick::TransparentOpacity)

    image = Magick::Image.read(source).first
    image_width  = image.columns
    image_height = image.rows

    width = image_width
    width = image_height if image_width > image_height

    canvas = Magick::Image.new(image_width, image_height)
    watermark.resize_to_fit!(width)
    canvas.composite_tiled!(watermark, Magick::OverCompositeOp)

    image.watermark(canvas, 0.05, 0.25, Magick::CenterGravity).write(target)

  end

  protected

  def init(source)
    @work = QuickMagick::Image.read(source).first
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
        Application.error('ImageConverter') { "JPEG2000 conversion failed: #{result}" }
      elsif result.match(/warning/i)
        Application.warn('ImageConverter') { "JPEG2000 conversion: #{result}" }
      end
      FileUtils.rm(tmp_file)
    else
      Application.debug('ImageConverter') { "command: convert #{@work.command_line}" }
      @work.write(target) { self.quality = q; self.filename = target }
    end
  end

end
