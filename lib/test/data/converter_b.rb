# coding: utf-8

require_relative 'test_converter'

class ConverterB < Converter
  include TestConverter

  def do_something( _ = {} )
  end

end