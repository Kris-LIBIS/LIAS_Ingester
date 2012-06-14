# coding: utf-8

require 'test/unit'
require 'tmpdir'
require 'fileutils'

$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'libis/record/sharepoint_record'

class TestMetadata < MiniTest::Unit::TestCase
  
=begin
  def test_node
    a = SharepointRecord.new
    a.node = 'abc'
    assert_equal('abc', a.node)
  end
=end

  def test_get_by_key()
    a = SharepointRecord.new
    a[:ows_ContentType] = 'Bestanddeel of stuk (document)'
    assert_equal('Bestanddeel of stuk (document)', a[:ows_ContentType], 'regular lookup')
    assert_equal('Bestanddeel of stuk (document)', a.simple_content_type, 'method lookup')
    assert_equal(nil, a[:no_value_to_expect], 'no match lookup')
  end
  
  def test_relative_path()
    a = SharepointRecord.new
    assert_equal(nil, a.relative_path, 'relative path')
    a[:ows_FileRef] = 'sites/lias/Gedeelde documenten/X/Y/Z/A.doc'
    assert_equal('X/Y/Z/A.doc', a.relative_path, 'relative path')
  end
  
  def test_local_path()
    a = SharepointRecord.new
    assert_equal(nil, a.local_path('X'))
    assert_equal(nil, a.local_path(nil))
    a[:ows_FileRef] = 'sites/lias/Gedeelde documenten/X/Y/Z/A.doc'
    assert_equal('Z/A.doc', a.local_path('X/Y'))
    assert_equal('Z/A.doc', a.local_path('X/Y/'))
    assert_equal('X/Y/Z/A.doc', a.local_path(nil))
    # maybe we should return a nil here or raise an exception?
    assert_equal('X/Y/Z/A.doc', a.local_path('X/Y/Z/A'))
  end
  
  def test_file_name()
    a = SharepointRecord.new
    assert_equal(nil, a.file_name)
    a[:ows_FileLeafRef] = 'A.doc'
    assert_equal('A.doc', a.file_name)
  end
  
  def test_content_type()
    a = SharepointRecord.new
    assert_equal(:unknown, a.simple_content_type)
    a[:ows_ContentType] = 'Something Unknown'
    assert_equal(:unknown, a.simple_content_type)
    a[:ows_ContentType] = 'Archief'
    assert_equal(:archive, a.simple_content_type)
    a[:ows_ContentType] = 'Bestanddeel of stuk (document)'
    assert_equal(:file, a.simple_content_type)
    a[:ows_ContentType] = 'Bestanddeel of stuk (document) (korte beschrijving)'
    assert_equal(:file, a.simple_content_type)
    a[:ows_ContentType] = 'Bestanddeel (folder)'
    assert_equal(:map, a.simple_content_type)
    a[:ows_ContentType] = 'Bestanddeel (folder) (korte beschrijving)'
    assert_equal(:map, a.simple_content_type)
    a[:ows_ContentType] = 'Meervoudige beschrijving (folder)'
    assert_equal(:mmap, a.simple_content_type)
    a[:ows_ContentType] = 'Meervoudige beschrijving (document)'
    assert_equal(:mfile, a.simple_content_type)
    a[:ows_ContentType] = 'Tussenniveau'
    assert_equal(:map, a.simple_content_type)
    a[:ows_ContentType] = 'Film'
    assert_equal(:file, a.simple_content_type)
    a[:ows_ContentType] = 'Object'
    assert_equal(:file, a.simple_content_type)
    a[:ows_ContentType] = 'Document'
    assert_equal(:file, a.simple_content_type)
  end
  
  def test_content_code()
    a = SharepointRecord.new
    assert_equal('-', a.content_code)
    a[:ows_ContentType] = 'Something Unknown'
    assert_equal('-', a.content_code)
    a[:ows_ContentType] = 'Archief'
    assert_equal('a', a.content_code)
    a[:ows_ContentType] = 'Bestanddeel of stuk (document)'
    assert_equal('f', a.content_code)
    a[:ows_ContentType] = 'Bestanddeel of stuk (document) (korte beschrijving)'
    assert_equal('f', a.content_code)
    a[:ows_ContentType] = 'Bestanddeel (folder)'
    assert_equal('m', a.content_code)
    a[:ows_ContentType] = 'Bestanddeel (folder) (korte beschrijving)'
    assert_equal('m', a.content_code)
    a[:ows_ContentType] = 'Meervoudige beschrijving (folder)'
    assert_equal('v', a.content_code)
    a[:ows_ContentType] = 'Meervoudige beschrijving (document)'
    assert_equal('<', a.content_code)
    a[:ows_ContentType] = 'Tussenniveau'
    assert_equal('m', a.content_code)
    a[:ows_ContentType] = 'Film'
    assert_equal('f', a.content_code)
    a[:ows_ContentType] = 'Object'
    assert_equal('f', a.content_code)
    a[:ows_ContentType] = 'Document'
    assert_equal('f', a.content_code)
  end
  
  def test_is_file()
    a = SharepointRecord.new
    assert(!a.is_file?)
    a[:ows_ContentType] = 'Something Unknown'
    assert(!a.is_file?)
    a[:ows_ContentType] = 'Bestanddeel of stuk (document)'
    assert( a.is_file?)
    a[:ows_ContentType] = 'Bestanddeel of stuk (document) (korte beschrijving)'
    assert( a.is_file?)
    a[:ows_ContentType] = 'Bestanddeel (folder)'
    assert(!a.is_file?)
    a[:ows_ContentType] = 'Bestanddeel (folder) (korte beschrijving)'
    assert(!a.is_file?)
    a[:ows_ContentType] = 'Meervoudige beschrijving (folder)'
    assert(!a.is_file?)
    a[:ows_ContentType] = 'Meervoudige beschrijving (document)'
    assert( a.is_file?)
    a[:ows_ContentType] = 'Tussenniveau'
    assert(!a.is_file?)
    a[:ows_ContentType] = 'Film'
    assert( a.is_file?)
    a[:ows_ContentType] = 'Object'
    assert( a.is_file?)
    a[:ows_ContentType] = 'Document'
    assert( a.is_file?)
  end
  
  def test_ingest_model()
    a = SharepointRecord.new
    assert_equal('Archiveren zonder manifestations', a.ingest_model)
    a[:ows_Ingestmodel] = 'jpg-watermark_jp2_tn'
    assert_equal('Afbeeldingen hoge kwaliteit', a.ingest_model)
    a[:ows_Ingestmodel] = 'jpg-watermark_jpg_tn'
    assert_equal('Afbeeldingen lage kwaliteit', a.ingest_model)
    a[:ows_Ingestmodel] = ''
    assert_equal('Archiveren zonder manifestations', a.ingest_model)
  end
  
  def test_create_dc()
    mapping = {
      normal: {name: 'Normal', tag: 'element'},
      prefixed: {name: 'Prefixed', prefix: '(before text) ', tag: 'prefixed_element'},
      postfixed: {name: 'Postfixed', tag: 'postfixed_element', postfix: ' (after text)'},
      bothfixed: {name: 'Bothfixed', prefix: '(before text) ', tag: 'bothfixed_element', postfix: ' (after text)'},
      namespace: {name: 'Namespace', tag: 'dc:element'}
    }
    
    a = SharepointRecord.new
    a[:index] = 1
    a[:normal] = 'normal text'
    a[:prefixed] = 'prefixed text'
    a[:postfixed] = 'postfixed text'
    a[:bothfixed] = 'bothfixed text'
    a[:namespace] = 'namespace text'
    
    dir = Dir.mktmpdir(['ruby-unit-test-', '.tmp'])
    a.create_dc(dir, mapping)
    
    dc_record = File.open(dir + '/dc_1.xml', 'r:utf-8').readlines.join
    FileUtils.rm_rf(dir)

    dc_expect = <<XML1
<?xml version="1.0" encoding="utf-8"?>
<record xmlns:dc="http://purl.org/dc/elements/1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:dcterms="http://purl.org/dc/terms">
  <#{mapping[:normal][:tag]}>#{a[:normal]}</#{mapping[:normal][:tag]}>
  <#{mapping[:prefixed][:tag]}>#{mapping[:prefixed][:prefix]}#{a[:prefixed]}</#{mapping[:prefixed][:tag]}>
  <#{mapping[:postfixed][:tag]}>#{a[:postfixed]}#{mapping[:postfixed][:postfix]}</#{mapping[:postfixed][:tag]}>
  <#{mapping[:bothfixed][:tag]}>#{mapping[:bothfixed][:prefix]}#{a[:bothfixed]}#{mapping[:bothfixed][:postfix]}</#{mapping[:bothfixed][:tag]}>
  <#{mapping[:namespace][:tag]}>#{a[:namespace]}</#{mapping[:namespace][:tag]}>
</record>
XML1
    assert_equal(dc_expect, dc_record, "Writing DC record failed")
    dc_expect = <<'XML2'
<?xml version="1.0" encoding="utf-8"?>
<record xmlns:dc="http://purl.org/dc/elements/1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:dcterms="http://purl.org/dc/terms">
  <element>normal text</element>
  <prefixed_element>(before text) prefixed text</prefixed_element>
  <postfixed_element>postfixed text (after text)</postfixed_element>
  <bothfixed_element>(before text) bothfixed text (after text)</bothfixed_element>
  <dc:element>namespace text</dc:element>
</record>
XML2
    assert_equal(dc_expect, dc_record, "Writing DC record failed")
    
  end
  
end

