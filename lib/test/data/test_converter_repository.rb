# coding: utf-8

require 'fileutils'
require 'converters/converter_repository'

class TestConverterRepository < ConverterRepository

  @@converters_glob = File.dirname(__FILE__) + '/converter_*.rb'

end