# coding: utf-8

#noinspection RubyResolve
require 'test_helper'

require 'application'

class TestCaSearch < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @ca = CollectiveAccess.new
    @ca.authenticate
    @object_label = 'TEST.0001.0001'
    @object_id = @ca.add_object @object_label

  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.
  def teardown
    @ca.delete_object @object_id
  end

  def test_01_search
    result = @ca.search.query(@object_label)
    #noinspection RubyStringKeysInHashInspection
    expected = {
        @object_id => {
            'display_label' => nil,
            'idno' => @object_label,
            'object_id' => @object_id
        }
    }
    assert_equal expected, result
  end

end