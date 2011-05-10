require 'rubygems'
require 'quick_magick'
require_relative 'converter'

class ImageConverter < Converter

  include QuickMagick

  attr_reader :work
  
  def initialized?
    @work != nil
  end

  def scale(percent)
    @work.append_to_settings('scale', percent)
  end

  def resize(geometry)
    @work.append_to_settings('resize',geometry)
  end

  def quality(value)
    @quality = value
    @work.append_to_settings('quality', value)
  end

  def get_watermark_file(dir, usage_type)
    "#{dir}/watermark_#{usage_type}.png"
  end

  #noinspection RubyResolve
  def create_watermark(text, dir, usage_type)
    
    file = get_watermark_file(dir, usage_type)
    return file if File.exist?(file)

    `#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_bin_dir']}/create_watermark.sh '#{file}' '#{(text.nil? ? ' (C) LIBIS' : text)}'`

    file

  end

  def watermark(source, target, watermark_image)
    `#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_bin_dir']}/watermarker.sh #{source} #{target} #{watermark_image}`
  end

  protected

  def init(source)
    @work = QuickMagick::Image.read(source).first
    Application.error('ImageConverter') { "QuickMagick cannot open image file '#{source}'."} unless @work
  end

  def do_convert(target,format)
    format = :JP2 if format == :JPEG2000
    @work.format = format.to_s if format
    Application.debug('ImageConverter') { "Writing conversion #{@work.inspect}" }
    q = @quality
    if format == :JP2
      @work.format = "BMP"
      tmp_file = target + '.tmp.bmp'
      @work.write(tmp_file) { |f| f.quality = q; f.filename = tmp_file }
      result = `j2kdriver -i #{tmp_file} -t jp2 -R 0 -w R53 -o #{target} 2>&1`
      if result.match(/error/i)
        Application.error('ImageConverter') { "JPEG2000 conversion failed: #{result}" }
      elsif result.match(/warning/i)
        Application.warn('ImageConverter') { "JPEG2000 conversion: #{result}" }
      end
      FileUtils.rm(tmp_file)
    else
      Application.debug('ImageConverter') { "command: convert #{@work.command_line}" }
      @work.write(target) { |f|  f.quality = q; f.filename = target }
    end
  end

end
