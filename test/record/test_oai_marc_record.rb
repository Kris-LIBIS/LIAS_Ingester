# coding: utf-8
#noinspection RubyResolve
require 'test_helper'

#noinspection RubyResolve
class TestOaiMarcRecord < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @record1 = RecordFactory.load('test/data/oai_marc.xml').first
    @record2 = RecordFactory.load('test/data/oai_present.xml').first
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_01_tag
    # oia_marc record
    assert_equal '   90178038 ',  @record1.tag('001').first.datas
    assert_equal nil,             @record1.tag('1').first
    assert_equal [],              @record1.tag('002')
    assert_equal 1,               @record1.tag('653').size
    assert_equal 1,               @record1.tag('653','a').size
    assert_equal 0,               @record1.tag('653','b').size
    assert_equal 0,               @record1.tag('653','ab').size
    assert_equal 1,               @record1.tag('653','a b').size
    # aleph present record
    assert_equal '110726u        be nnn            m|dut d', @record2.tag('008').first.datas
    assert_equal 1,               @record2.tag('CAT').size
    assert_equal 'VM',            @record2.tag('FMT').first.datas
  end

  def test_02_subfield
    assert_equal '90178038',                @record1.each_field('010','a').first
    assert_equal ['Berthou, P. Y.','(Pierre Yves)'], @record1.each_field('100','aq')
    assert_equal ['Berthou, P. Y.','(Pierre Yves)'], @record1.all_fields('100','a q')
    assert_equal ['Berthou, P. Y.','(Pierre Yves)'], @record1.all_fields('100','qa')
    assert_equal 'Stratigraphic geology;',  @record1.tag('653').first.field('a')
    assert_equal 'Cenomanian deposits;',    @record1.tag('653').first.field_array('a')[1]
    assert_equal 'Portugal',                @record1.tag('653').first.fields_array('a')[2]
    assert_equal 'Portugal',                @record1.all_fields('653','a')[2]
    assert_equal 3,                         @record1.all_fields('653','a').size
    assert_equal 'Static image',            @record2.each_field('24500','h').first
  end

end