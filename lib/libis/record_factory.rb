# coding: utf-8

#noinspection RubyResolve

require 'tools/xml_document'

require 'libis/record/oai_marc_record'
require 'libis/record/marc21_record'

class RecordFactory

  def self.load(xml_file)
    get_marc_records(XmlDocument.open(xml_file))
  end

  def self.parse(xml_string)
    get_marc_records(XmlDocument.parse(xml_string))
  end

  private

  def self.get_marc_records(xml_document)
    xml_document.document.remove_namespaces!
    oai_marc_records = xml_document.root.xpath('//oai_marc')
    return oai_marc_records.collect { |x| OaiMarcRecord.new(x) } unless oai_marc_records.empty?
    marc21_records = xml_document.root.xpath('//record')
    marc21_records.collect { |x| Marc21Record.new(x) }
  end

end
