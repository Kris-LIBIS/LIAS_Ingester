#encoding: UTF-8
require 'application'
require 'tools/mime_type'

require_relative 'converter'

class PdfConverter < Converter

  def initialized?
    !@source.nil?
  end

  def range(selection)
    @options[:ranges] = selection
  end

  def watermark(watermark_info, watermark_file)
    if watermark_info.nil?
      @wm_text = [ '© LIBIS' ]
    elsif File.exist? watermark_info
      @wm_image = watermark_info
    else
      @wm_text = watermark_info.spit('\n')
    end

  end

  protected

  def init(source)
    @options ||= {}
    @source = source

    unless support_input_mimetype?(MimeType.get(@source))
      Application.instance().logger.error(self.class) { "Supplied file '#{@source}' is not a PDF file." }
    end


  end

  def do_convert(target, format)

    cmd = "#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_bin_dir']}/pdf_copy.sh --file_input \"#{source}\" --file_output \"#{target}\""

    @options.each do |k,v|
      cmd += " --#{k.to_s} #{v}"
    end

    cmd += " --wm_image \"#{@wm_image}\"" if @wm_image

    if @wm_text
      cmd += " --wm_text"
      @wm_text.each { |t| cmd += " \"#{t}\"" }
    end

    `#{cmd}`

  end

end