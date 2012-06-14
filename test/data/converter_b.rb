# coding: utf-8

require 'helpers/dummy_converter'

class ConverterB < Converter
  include DummyConverter

  def do_something( _ = {} )
  end

end
