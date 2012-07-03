# coding: utf-8
#noinspection RubyResolve
require 'test_helper'

require 'application'

class TestCaItemInfo < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup

    @ca_client = CollectiveAccess.new
    @ca_client.authenticate
    @object_label = 'TEST.0001.0001'
    @object = @ca_client.add_object @object_label
    @attributes = {
        digitoolUrl: %w(abcdefgh 172 DigitoolUrl),
        objectHistoriek: %w(blablabla 84 Text),
        objectBeschrijving: %w(zxcvbnm 91 Text)
    }
    @attributes.each { |k, v|
      @ca_client.add_attribute @object, k, v[0]
    }

    @client ||= CaItemInfo.new()
    @client.authenticate
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    @ca_client.delete_object @object
  end

  def test_01_attributes
    result = @client.get_attributes(@object)

    assert_equal @attributes.size, result.size
    @attributes.each_with_index { |(k, v), i|
      check_attribute result, i, v[0], v[1], k.to_s, v[2]
    }
  end

  def test_02_attribute
    @attributes.each { |k, v|
      result = @client.get_attribute @object, k.to_s
      check_attribute [result], 0, v[0], v[1]
    }
  end

  def check_attribute(result, nr, display_value, element_id, element_code = nil, datatype = nil)
    r = result
    (nr.is_a?(Array) ? nr : [nr]).each { |i| r = r[i] }
    assert_equal display_value, r['display_value']
    assert_equal element_code, r['element_code']
    assert_equal element_id, r['element_id']
    assert_equal datatype, r['datatype']
  end

end