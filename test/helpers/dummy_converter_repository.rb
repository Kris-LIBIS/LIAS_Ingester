# coding: utf-8

require 'fileutils'
require 'converters/converter_repository'

class DummyConverterRepository < ConverterRepository

  @@converters_glob = 'test/data/converter_*.rb'

end
