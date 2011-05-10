require_relative 'converter'

class VideoConverter < Converter
  
  protected

  def init(source)
    puts "Initializing #{self.class} with '#{source}'"
  end

  def do_convert(target, format)
    puts "#{self.class}::do_convert(#{target},#{format})"
  end

end
