require_relative 'test_converter'

class ConverterB < Converter
  include TestConverter

  def do_something( options = {} )
  end

end