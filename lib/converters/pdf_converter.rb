class PdfConverter

  def initialized?
    return true
  end

  protected

  def init(source)
    @source = source

    puts "Initializing #{self.class} with '#{source}'"
    load_config Application.dir + '/config/converters/pdf_converter.yaml'
  end

  def do_convert(target, format)
    puts "#{self.class}::do_convert(#{target},#{format})"
  end

end