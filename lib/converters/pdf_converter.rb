require_relative 'converter'

class PdfConverter < Converter

  def initialized?
    true
  end

  protected

  def init(source)
    @source = source

    puts "Initializing #{self.class} with '#{source}'"
  end

  def do_convert(target, format)
    puts "#{self.class}::do_convert(#{target},#{format})"
  end

end