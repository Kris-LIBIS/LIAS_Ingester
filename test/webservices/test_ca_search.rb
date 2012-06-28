# coding: utf-8

#noinspection RubyResolve
require 'test_helper'

require 'application'

class TestCaSearch < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @client ||= CaSearch.new()
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
  end

  def test_01_authorize
    assert_equal false, @client.authenticate('dummy', 'dummy')
    assert_equal true, @client.authenticate
  end

  def test_02_search
    term = 'CRKC.0003.0011'
    @client.authenticate
    result = @client.query(term)
    #noinspection RubyStringKeysInHashInspection
    expected = {
        '9031' => {
            'display_label' => 'H. Margaretha van Budapest',
            'idno' => 'CRKC.0003.0011 - (KV_6631)',
            'object_id' => '9031'
        }
    }
    assert_equal expected, result
  end

end