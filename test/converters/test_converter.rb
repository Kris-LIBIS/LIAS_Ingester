# coding: utf-8

require "test_helper"

require 'helpers/dummy_converter_repository'

class TestConverter < MiniTest::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @old_db_level = Application.instance.db_log_level
    @old_log_level = Application.instance.logger.level
    Application.instance.db_log_level = 4
    Application.instance.logger.level = 4
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    Application.instance.db_log_level = @old_db_level
    Application.instance.logger.level = @old_log_level
  end

  def test_chain
    chain = DummyConverterRepository.get_converter_chain :DOC, :XLS
    assert_equal([{:converter => ConverterA, :target => :XLS}], chain.to_array)
    chain = DummyConverterRepository.get_converter_chain :XLS, :PDF
    assert_equal([{:converter => ConverterA, :target => :PDFA}, {:converter => ConverterB, :target => :PDF}], chain.to_array)
    chain = DummyConverterRepository.get_converter_chain :DOC, :GIF
    assert_equal([{:converter  => ConverterA, :target  => :PDFA}, {:converter => ConverterD, :target => :JPEG}, {:converter => ConverterE, :target => :GIF}], chain.to_array)
  end

  def test_chain_operations
    chain = DummyConverterRepository.get_converter_chain :DOC, :JPEG
    assert_equal([{:converter => ConverterA, :target => :PDFA}, {:converter => ConverterD, :target => :JPEG}], chain.to_array)
    chain = DummyConverterRepository.get_converter_chain :DOC, :JPEG, { :DUMMY => nil }
    assert_nil(chain)
    chain = DummyConverterRepository.get_converter_chain :DOC, :JPEG, { :DO_SOMETHING => nil }
    assert_equal([{:converter => ConverterA, :target => :PDFA}, {:converter => ConverterB, :target => :PDFA}, {:converter => ConverterD, :target => :JPEG}], chain.to_array)
  end
end
