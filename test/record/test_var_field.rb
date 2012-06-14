# coding: utf-8

require "test_helper"

class TestVarField < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  #noinspection RubyStringKeysInHashInspection
  def setup

    subfields = {
        'a' => %w(a1 a2),
        'b' => %w(b1 b2),
        'c' => %w(c1 c2),
    }
    @v_abc = VarField.new('999', '9', '9', subfields)

    subfields = {
        'a' => %w(a1 a2),
        'b' => %w(b1 b2),
    }
    @v_ab_ = VarField.new('999', '9', '9', subfields)

    subfields = {
        'a' => %w(a1 a2),
        'c' => %w(c1 c2),
    }
    @v_a_c = VarField.new('999', '9', '9', subfields)

    subfields = {
        'c' => %w(c1 c2),
        'b' => %w(b1 b2),
        'a' => %w(a1 a2),
        '3' => %w(31 32),
        '2' => %w(21 22),
        '1' => %w(11 12),
    }
    @v_cba321 = VarField.new('999', '9', '9', subfields)

  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_01_keys

    assert_equal %w(a b c), @v_abc.keys
    assert_equal %w(a b  ), @v_ab_.keys
    assert_equal %w(a   c), @v_a_c.keys
  end

  def test_02_field_array

    assert_equal %w(a1 a2), @v_abc.field_array('a')
    assert_equal %w(b1 b2), @v_abc.field_array('b')
    assert_equal %w(c1 c2), @v_abc.field_array('c')

  end

  def test_03_field

    assert_equal 'a1', @v_abc.field('a')
    assert_equal 'b1', @v_abc.field('b')
    assert_equal 'c1', @v_abc.field('c')

  end

  def test_04_fields

    assert_equal %w(a1 b1 c1), @v_abc.fields('abc')
    assert_equal %w(a1 b1   ), @v_ab_.fields('abc')
    assert_equal %w(a1    c1), @v_a_c.fields('abc')

    # test sorting
    #            %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32)
    assert_equal %w(a1    b1    c1                     ), @v_cba321.fields('abc')
    assert_equal %w(a1    b1    c1    11    21    31   ), @v_cba321.fields('abc123')
    assert_equal %w(11    21    31    a1    b1    c1   ), @v_cba321.fields('123abc')
    assert_equal %w(b1    21    c1    11    a1    31   ), @v_cba321.fields('b2c1a3')
    assert_equal %w(b1    31                a1    21   ), @v_cba321.fields('b3a2')

  end

  def test_05_fields_array

    assert_equal %w(a1 a2 b1 b2 c1 c2), @v_abc.fields_array('abc')
    assert_equal %w(a1 a2 b1 b2      ), @v_ab_.fields_array('abc')
    assert_equal %w(a1 a2       c1 c2), @v_a_c.fields_array('abc')

    # test sorting
    assert_equal %w(a1 a2 b1 b2 c1 c2                  ), @v_cba321.fields_array('abc')
    assert_equal %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32), @v_cba321.fields_array('abc123')
    assert_equal %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32), @v_cba321.fields_array('123abc')
    assert_equal %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32), @v_cba321.fields_array('b2c1a3')
    assert_equal %w(a1 a2 b1 b2             21 22 31 32), @v_cba321.fields_array('b3a2')

  end

  def test_06_match_fieldspec

    assert @v_abc.match_fieldspec?('a')
    assert @v_abc.match_fieldspec?('b')
    assert @v_abc.match_fieldspec?('c')
    assert @v_abc.match_fieldspec?('ab')
    assert @v_abc.match_fieldspec?('ac')
    assert @v_abc.match_fieldspec?('abc')

    assert @v_ab_.match_fieldspec?('a')
    assert @v_ab_.match_fieldspec?('b')
    assert !@v_ab_.match_fieldspec?('c')
    assert @v_ab_.match_fieldspec?('ab')
    assert !@v_ab_.match_fieldspec?('ac')
    assert !@v_ab_.match_fieldspec?('abc')

    assert @v_a_c.match_fieldspec?('a')
    assert !@v_a_c.match_fieldspec?('b')
    assert @v_a_c.match_fieldspec?('c')
    assert !@v_a_c.match_fieldspec?('ab')
    assert @v_a_c.match_fieldspec?('ac')
    assert !@v_a_c.match_fieldspec?('abc')

    assert !@v_abc.match_fieldspec?('ab-c')
    assert @v_ab_.match_fieldspec?('ab-c')
    assert !@v_a_c.match_fieldspec?('ab-c')

    assert !@v_abc.match_fieldspec?('a-bc')
    assert !@v_abc.match_fieldspec?('a-b')
    assert !@v_abc.match_fieldspec?('a-c')

  end

  def test_07_method_unknown

    ####### we redo the tests with shorthand notation

    # test 02
    assert_equal %w(a1 a2), @v_abc.a_a
    assert_equal %w(b1 b2), @v_abc.a_b
    assert_equal %w(c1 c2), @v_abc.a_c

    # test 03

    assert_equal 'a1', @v_abc.f_a
    assert_equal 'b1', @v_abc.f_b
    assert_equal 'c1', @v_abc.f_c

    assert_equal 'a1', @v_abc._a
    assert_equal 'b1', @v_abc._b
    assert_equal 'c1', @v_abc._c

    # test 04

    assert_equal %w(a1 b1 c1), @v_abc.f_abc
    assert_equal %w(a1 b1   ), @v_ab_.f_abc
    assert_equal %w(a1    c1), @v_a_c.f_abc

    assert_equal %w(a1 b1 c1), @v_abc._abc
    assert_equal %w(a1 b1   ), @v_ab_._abc
    assert_equal %w(a1    c1), @v_a_c._abc

    # test sorting
    #            %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32)
    assert_equal %w(a1    b1    c1                     ), @v_cba321.f_abc
    assert_equal %w(a1    b1    c1    11    21    31   ), @v_cba321.f_abc123
    assert_equal %w(11    21    31    a1    b1    c1   ), @v_cba321.f_123abc
    assert_equal %w(b1    21    c1    11    a1    31   ), @v_cba321.f_b2c1a3
    assert_equal %w(b1    31                a1    21   ), @v_cba321.f_b3a2

    assert_equal %w(a1    b1    c1                     ), @v_cba321._abc
    assert_equal %w(a1    b1    c1    11    21    31   ), @v_cba321._abc123
    assert_equal %w(11    21    31    a1    b1    c1   ), @v_cba321._123abc
    assert_equal %w(b1    21    c1    11    a1    31   ), @v_cba321._b2c1a3
    assert_equal %w(b1    31                a1    21   ), @v_cba321._b3a2

    # test 05

    assert_equal %w(a1 a2 b1 b2 c1 c2), @v_abc.a_abc
    assert_equal %w(a1 a2 b1 b2      ), @v_ab_.a_abc
    assert_equal %w(a1 a2       c1 c2), @v_a_c.a_abc

    # test sorting
    assert_equal %w(a1 a2 b1 b2 c1 c2                  ), @v_cba321.a_abc
    assert_equal %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32), @v_cba321.a_abc123
    assert_equal %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32), @v_cba321.a_123abc
    assert_equal %w(a1 a2 b1 b2 c1 c2 11 12 21 22 31 32), @v_cba321.a_b2c1a3
    assert_equal %w(a1 a2 b1 b2             21 22 31 32), @v_cba321.a_b3a2

  end

end