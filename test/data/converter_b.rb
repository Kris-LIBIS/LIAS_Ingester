# coding: utf-8

#noinspection RubyResolve
require 'helpers/dummy_converter'

class ConverterB < Converter
  #noinspection RubyResolve
  include DummyConverter

  def do_something( _ = {} )
  end

end
