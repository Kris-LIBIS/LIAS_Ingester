# coding: utf-8
#noinspection RubyResolve
require 'test_helper'

require 'application'

class TestCaItemInfo < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @client ||= CaItemInfo.new()
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
  end

  def test_01_attributes
    @client.authenticate
    result = @client.attributes(9031)

    assert 7 < result.size
    check_attribute result, 0, '63416', 'herkomst: rozenkransbroederschapafkomstig van processievaandelrestauratie: RVW', '84', 'objectHistoriek', 'Text'
    check_attribute result, 1, '63418', nil, '84', 'objectHistoriek', 'Text'
    check_attribute result, 2, '63417', 'Portret van de H. Margaretha van Budapest uit reeks van 17 portretten van resp. 6 vrouwelijke en 11 mannelijke heiligen van de Dominicaanse orde.Afkomstig van processievaandels. kunstenaar: St . Lucasschool', '91', 'objectBeschrijving', 'Text'
    check_attribute result, 3, '181535', '7081', '145', 'trefwoordList', 'List'
    assert_equal 2, result[4].size
    check_attribute result, [4, 0], '315652', '1071', '148', 'objectTechniekType', 'List'
    check_attribute result, [4, 1], '315653', nil, '150', 'objectTechniekOpmerking', 'Text'
    check_attribute result, 5, '364873', '55509_,_http://libis-t-rosetta-1.libis.kuleuven.be/lias/cgi/get_pid?redirect&usagetype=THUMBNAIL&pid=55509&custom_att_3=stream_,_http://libis-t-rosetta-1.libis.kuleuven.be/lias/cgi/get_pid?redirect&usagetype=VIEW_MAIN,VIEW&pid=55509', '172', 'digitoolUrl', 'DigitoolUrl'
  end

  def test_02_attribute
    @client.authenticate
    result = @client.attribute 9031, 'digitoolUrl'

    assert 0 < result.size
    check_attribute result, 0, '364873', '55509_,_http://libis-t-rosetta-1.libis.kuleuven.be/lias/cgi/get_pid?redirect&usagetype=THUMBNAIL&pid=55509&custom_att_3=stream_,_http://libis-t-rosetta-1.libis.kuleuven.be/lias/cgi/get_pid?redirect&usagetype=VIEW_MAIN,VIEW&pid=55509', '172'

  end

  def check_attribute(result, nr, value_id, display_value, element_id, element_code = nil, datatype = nil)
    r = result
    (nr.is_a?(Array) ? nr : [nr]).each { |i| r = r[i] }
    assert_equal(value_id, r['value_id'])
    assert_equal(display_value, r['display_value'])
    assert_equal(element_code, r['element_code'])
    assert_equal(element_id, r['element_id'])
    assert_equal(datatype, r['datatype'])
  end

end