# coding: utf-8
#noinspection RubyResolve
require 'test_helper'

class TestMarc21Record < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @record = RecordFactory.load('test/data/marc21.xml').first
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_01_controlfields
    assert_equal('01142cam  2200301 a 4500', @record.tag('LDR').first.datas)
    assert_equal('   92005291 ', @record.tag('001').first.datas)
    assert_equal('920219s1993    caua   j      000 0 eng  ', @record.tag('008').first.datas)
  end

  def test_02_datafields
    assert_equal 1,@record.tag('050').size
    assert_equal('A88 1993',@record.tag('050').first.field('b'))
    assert_equal(@record.tag('050').first.field('b'), @record.each_field('050','b').first)
    assert_equal(5, @record.tag('650','a x').size)
    assert_equal(2, @record.tag('650','ax').size)
  end
end