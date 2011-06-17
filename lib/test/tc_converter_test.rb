$: << File.expand_path(File.dirname(__FILE__) + '/..')

require "test/unit"

require_relative 'data/test_converter_repository'

class ConverterTest < MiniTest::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_chain
    chain = TestConverterRepository.get_converter_chain :DOC, :XLS
    assert_equal([{:converter => ConverterA, :target => :XLS}], chain.to_array)
    chain = TestConverterRepository.get_converter_chain :XLS, :PDF
    assert_equal([{:converter => ConverterA, :target => :PDFA}, {:converter => ConverterB, :target => :PDF}], chain.to_array)
    chain = TestConverterRepository.get_converter_chain :DOC, :GIF
    assert_equal([{:converter  => ConverterA, :target  => :PDFA}, {:converter => ConverterD, :target => :JPEG}, {:converter => ConverterE, :target => :GIF}], chain.to_array)
  end
end