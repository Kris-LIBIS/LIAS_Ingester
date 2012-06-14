# coding: utf-8

require 'test_helper'

require 'test/helpers/unixdiff'

class TestMarcRecord < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    xml = <<XML_END
<collection>
  <record>
    <leader>1234567890</leader>
    <controlfield tag="001">001-1234567890</controlfield>
    <controlfield tag="002">002-1</controlfield>
    <controlfield tag="002">002-2</controlfield>
    <datafield tag="100" ind1=" " ind2=" ">
      <subfield code="a">100-1-a1</subfield>
      <subfield code="a">100-1-a2</subfield>
      <subfield code="b">100-1-b1</subfield>
      <subfield code="b">100-1-b2</subfield>
      <subfield code="c">100-1-c1</subfield>
      <subfield code="c">100-1-c2</subfield>
    </datafield>
  </record>
  <record>
    <leader>0123456789</leader>
    <controlfield tag="001">001-9876543210</controlfield>
    <datafield tag="100" ind1=" " ind2=" ">
      <subfield code="a">100-1-a1</subfield>
      <subfield code="a">100-1-a2</subfield>
      <subfield code="b">100-1-b1</subfield>
    </datafield>
    <datafield tag="100" ind1=" " ind2=" ">
      <subfield code="a">100-2-a1</subfield>
      <subfield code="a">100-2-a2</subfield>
      <subfield code="c">100-2-c1</subfield>
    </datafield>
    <datafield tag="100" ind1=" " ind2=" ">
      <subfield code="a">100-3-a1</subfield>
      <subfield code="a">100-3-a2</subfield>
      <subfield code="b">100-3-b1</subfield>
      <subfield code="c">100-3-c1</subfield>
    </datafield>
  </record>
</collection>
XML_END
    @record1, @record2 = RecordFactory.parse(xml)
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_00
    rec1 = <<REC1_DUMP
LDR:'1234567890'
001:'001-1234567890'
002:'002-1'
002:'002-2'
100: : :
	a:["100-1-a1", "100-1-a2"]
	b:["100-1-b1", "100-1-b2"]
	c:["100-1-c1", "100-1-c2"]
REC1_DUMP

    rec2 = <<REC2_DUMP
LDR:'0123456789'
001:'001-9876543210'
100: : :
	a:["100-1-a1", "100-1-a2"]
	b:["100-1-b1"]
100: : :
	a:["100-2-a1", "100-2-a2"]
	c:["100-2-c1"]
100: : :
	a:["100-3-a1", "100-3-a2"]
	b:["100-3-b1"]
	c:["100-3-c1"]
REC2_DUMP

    assert_equal rec1, @record1.dump
    assert_equal rec2, @record2.dump

  end

  #noinspection RubyResolve
  def test_01_tag
    assert_equal '1234567890', @record1.tag('LDR').first.datas
    assert_equal '0123456789', @record2.tag('LDR').first.datas

    assert_equal 1, @record1.tag('001').size
    assert_equal '001-1234567890', @record1.tag('001').first.datas

    assert_equal 1, @record2.tag('001').size
    assert_equal '001-9876543210', @record2.tag('001').first.datas

    assert_equal 2, @record1.tag('002').size
    assert_equal %w(002-1 002-2), @record1.tag('002').collect { |r| r.datas }

    assert_equal 0, @record2.tag('002').size

    assert_equal 1, @record1.tag('100').size
    assert_equal 0, @record1.tag('1001').size

    assert_equal 1, @record1.tag('100', 'a').size
    assert_equal 1, @record1.tag('100', 'ab').size
    assert_equal 1, @record1.tag('100', 'b').size
    assert_equal 1, @record1.tag('100', 'abc').size
    assert_equal 1, @record1.tag('100', 'a b c').size
    assert_equal 0, @record1.tag('100', 'x').size
    assert_equal 1, @record1.tag('100', 'a b x').size
    assert_equal 0, @record1.tag('100', 'abx').size

    assert_equal 3, @record2.tag('100', 'a').size
    assert_equal 2, @record2.tag('100', 'b').size
    assert_equal 2, @record2.tag('100', 'c').size
    assert_equal 3, @record2.tag('100', 'a b').size
    assert_equal 2, @record2.tag('100', 'ab').size
    assert_equal 3, @record2.tag('100', 'a c').size
    assert_equal 2, @record2.tag('100', 'ac').size
    assert_equal 3, @record2.tag('100', 'a b c').size
    assert_equal 1, @record2.tag('100', 'abc').size
    assert_equal 3, @record2.tag('100', 'a b c x').size
    assert_equal 0, @record2.tag('100', 'abcx').size
  end

  def test_02_each_field
    assert_equal %w(100-1-a1), @record1.each_field('100', 'a')
    assert_equal %w(100-1-b1), @record1.each_field('100', 'b')
    assert_equal %w(100-1-c1), @record1.each_field('100', 'c')
    assert_equal %w(100-1-a1 100-1-b1), @record1.each_field('100', 'ab')
    assert_equal %w(100-1-a1 100-1-c1), @record1.each_field('100', 'ac')
    assert_equal %w(100-1-a1 100-1-b1 100-1-c1), @record1.each_field('100', 'abc')

    assert_equal %w(100-1-a1 100-2-a1 100-3-a1), @record2.each_field('100', 'a')
    assert_equal %w(100-1-b1 100-3-b1), @record2.each_field('100', 'b')
    assert_equal %w(100-2-c1 100-3-c1), @record2.each_field('100', 'c')
    assert_equal %w(100-1-a1 100-1-b1 100-3-a1 100-3-b1), @record2.each_field('100', 'ab')
    assert_equal %w(100-2-a1 100-2-c1 100-3-a1 100-3-c1), @record2.each_field('100', 'ac')
    assert_equal %w(100-3-a1 100-3-b1 100-3-c1), @record2.each_field('100', 'abc')

    assert_equal %w(100-1-a1 100-1-b1 100-2-a1 100-3-a1 100-3-b1), @record2.each_field('100', 'a b')
    assert_equal %w(100-1-a1 100-2-a1 100-2-c1 100-3-a1 100-3-c1), @record2.each_field('100', 'a c')
    assert_equal %w(100-1-a1 100-1-b1 100-2-a1 100-2-c1 100-3-a1 100-3-b1 100-3-c1), @record2.each_field('100', 'a b c')
  end

  def test_03_all_fields
    assert_equal %w(100-1-a1 100-1-a2), @record1.all_fields('100', 'a')
    assert_equal %w(100-1-b1 100-1-b2), @record1.all_fields('100', 'b')
    assert_equal %w(100-1-c1 100-1-c2), @record1.all_fields('100', 'c')

    assert_equal %w(100-1-a1 100-1-a2 100-1-b1 100-1-b2), @record1.all_fields('100', 'ab')
    assert_equal %w(100-1-a1 100-1-a2 100-1-c1 100-1-c2), @record1.all_fields('100', 'ac')
    assert_equal %w(100-1-a1 100-1-a2 100-1-b1 100-1-b2 100-1-c1 100-1-c2), @record1.all_fields('100', 'abc')

    assert_equal %w(100-1-a1 100-1-a2 100-2-a1 100-2-a2 100-3-a1 100-3-a2), @record2.all_fields('100', 'a')
    assert_equal %w(100-1-b1 100-3-b1), @record2.all_fields('100', 'b')
    assert_equal %w(100-2-c1 100-3-c1), @record2.all_fields('100', 'c')

    assert_equal %w(100-1-a1 100-1-a2 100-1-b1 100-3-a1 100-3-a2 100-3-b1), @record2.all_fields('100', 'ab')
    assert_equal %w(100-2-a1 100-2-a2 100-2-c1 100-3-a1 100-3-a2 100-3-c1), @record2.all_fields('100', 'ac')
    assert_equal %w(100-3-a1 100-3-a2 100-3-b1 100-3-c1), @record2.all_fields('100', 'abc')

    assert_equal %w(100-1-a1 100-1-a2 100-1-b1 100-2-a1 100-2-a2 100-3-a1 100-3-a2 100-3-b1), @record2.all_fields('100', 'a b')
    assert_equal %w(100-1-a1 100-1-a2 100-2-a1 100-2-a2 100-2-c1 100-3-a1 100-3-a2 100-3-c1), @record2.all_fields('100', 'a c')
    assert_equal %w(100-1-a1 100-1-a2 100-1-b1 100-2-a1 100-2-a2 100-2-c1 100-3-a1 100-3-a2 100-3-b1 100-3-c1), @record2.all_fields('100', 'a b c')

  end

  def test_04_to_dc_sample_records


    %w( 8388627-1 8388647-1 8388659-1 8388680-1 8388823-1 8389207-1 8389246-1 8389280-1 ).each { |name|

      filename = 'test/data/' + name + '.xml'
      records = RecordFactory.load filename

      dc_record = records.first.to_dc
      ref_doc = XmlDocument::open('test/data/dc_' + name + '.xml')

      dc_xml = dc_record.document.root.element_children.collect { |node| node.to_xml(encoding: 'utf-8') }
      ref_xml = ref_doc.document.root.element_children.collect { |node| node.to_xml }

      if true
        if dc_xml != ref_xml
          diffmsg = StringIO.new
          diff = Diff.new(ref_xml, dc_xml)
          diff.to_diff(diffmsg)
          assert(false, "Error in record '#{name}:\n" + diffmsg.string)
        end
      else
        assert_equal(ref_xml, dc_xml)
      end

    }
  end

end
