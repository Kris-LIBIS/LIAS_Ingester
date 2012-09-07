# coding: utf-8
#noinspection RubyResolve
require 'test_helper'

class TestDcElement < Test::Unit::TestCase

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

  # Fake test
  def test_01_arguments
    x = DcElement.new 'abc'
    assert_equal 'abc', x.to_s
    x.join = '-'
    assert_equal 'abc', x.to_s
    x = DcElement.new %w(a b c)
    assert_equal 'abc', x.to_s
    x.join = '-'
    assert_equal 'a-b-c', x.to_s
    x.prefix = '['
    assert_equal '[a-b-c', x.to_s
    x.postfix = ']'
    assert_equal '[a-b-c]', x.to_s
    x = DcElement.new 'a' , 'b', %w(c d), 'e', join: ':', prefix: '->', postfix: '.'
    assert_equal '->a:b:c:d:e.', x.to_s
    x = DcElement.from %w(a b c), join: '-', fix: '{}'
    assert_equal '{a-b-c}', x.to_s
    x = DcElement.from ['a' , 'b', %w(c d), 'e'], join: ':', prefix: '->', postfix: '.'
    assert_equal '->a:b:c:d:e.', x.to_s
    x = DcElement.from parts: ['a' , 'b', %w(c d), 'e'], join: ':', prefix: '->', postfix: '.'
    assert_equal '->a:b:c:d:e.', x.to_s
    x = DcElement.from 'a' , 'b', %w(c d), 'e', join: ':', prefix: '->', postfix: '.'
    assert_equal '->a:b:c:d:e.', x.to_s
  end

  def test_02_options
    x = DcElement.new %w(a b c)
    assert_equal 'abc', x.to_s
    x = DcElement.new %w(a b c), join: '-'
    assert_equal 'a-b-c', x.to_s
    x = DcElement.new %w(a b c), join: '-', prefix: '['
    assert_equal '[a-b-c', x.to_s
    x = DcElement.new %w(a b c), join: '-', prefix: '[', postfix: ']'
    assert_equal '[a-b-c]', x.to_s
    x = DcElement.new %w(a b c), prefix: ':)'
    assert_equal ':)abc', x.to_s
    x = DcElement.new %w(a b c), fix: '{}'
    assert_equal '{abc}', x.to_s
  end

  def test_03_complex
    x = DcElement.new %w(a b c), join: ',', prefix: '[', postfix: ']'
    y = DcElement.new %w(x y), join: '-', prefix: '{', postfix: '}'
    y.parts << x
    y.parts << 'z'
    assert_equal '{x-y-[a,b,c]-z}', y.to_s
    x = DcElement.new 'a', { parts: %w(b c), join: ':', fix: '()'}, 'd', join: ',', fix: '<>'
    assert_equal '<a,(b:c),d>', x.to_s
    x = DcElement.new 'a', { parts: 'b', join: ':', fix: '()'}, 'd', join: ',', fix: '<>'
    assert_equal '<a,(b),d>', x.to_s
    x = DcElement.new 'a', { parts: %w(b c), join: ':', fix: '()'}, join: ',', fix: '<>'
    assert_equal '<a,(b:c)>', x.to_s
    x = DcElement.new 'a', nil, { parts: ['b', nil, 'c'], join: ':', fix: '()'}, nil, join: ',', fix: '<>'
    assert_equal '<a,(b:c)>', x.to_s, 'Ignore extra nils'
    # the extra nil is required to prevent the hash to be consumed in the root element (see next test)
    x = DcElement.new 'a', { parts: %w(b c), join: ':', fix: '()'}, nil
    assert_equal 'a(b:c)', x.to_s
    x = DcElement.new 'a', { parts: %w(b c), join: ':', fix: '()'}
    assert_equal '(a:b:c)', x.to_s
    x = DcElement.new 'a', prefix: {parts: '1', postfix: '.'}, postfix: {parts: %w(2 3), join: '.', prefix: '_'}
    assert_equal '1.a_2.3', x.to_s
  end

end