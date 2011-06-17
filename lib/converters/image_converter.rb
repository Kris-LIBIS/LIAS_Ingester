#encoding: UTF-8
require_relative 'converter'

class ImageConverter < Converter

  def initialized?
    !@source.nil?
  end

  def scale(percent)
    @options[:scale] = percent
  end

  def resize(geometry)
    @options[:resize] = geometry
  end

  def quality(value)
    @options[:quality] = value
  end

  def watermark(watermark_info, watermark_file)
    watermark_image = watermark_info
    unless watermark_image and File.exist? watermark_image
      watermark_image = watermark_file + ".png"
    end
    unless File.exist?(watermark_image)
      watermark_info = '© LIBIS' if watermark_info.nil?
      `#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_bin_dir']}/create_watermark.sh '#{watermark_image}' '#{watermark_info}'`
    end
    @wm_image = watermark_image
  end

  protected

  def init(source)
    @options ||= {}
    @source = source
    Application.error('ImageConverter') { "QuickMagick cannot open image file '#{source}'."} unless File.exist? source
  end

  def do_convert(target,format)
    target_file = target
    target_format = format
    target_format = :JP2 if target_format == :JPEG2000
    if target_format == :JP2
      target_format = "BMP"
      target_file += '.tmp.bmp'
    end

    command = "convert"
    command = "#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_bin_dir']}/watermarker.sh" if @wm_image

    @options.each do |o,v|
      command += " -#{o.to_s} '#{v}'"
    end

    command += " '#{@source}' '#{target_file}'"

    command += " '#{@wm_image}'" if @wm_image

    Application.debug('ImageConverter') { "command: #{command}" }

    result = `#{command}`

    Application.debug('ImageConverter') { "result: #{result}" }

    if format == :JPEG2000
      result = `j2kdriver -i #{target_file} -t jp2 -R 0 -w R53 -o #{target} 2>&1`
      if result.match(/error/i)
        Application.error('ImageConverter') { "JPEG2000 conversion failed: #{result}" }
      elsif result.match(/warning/i)
        Application.warn('ImageConverter') { "JPEG2000 conversion: #{result}" }
      end
      FileUtils.rm(target_file)
      target_file = target
    end

    target_file

  end

end
