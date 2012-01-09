# coding: utf-8

require 'tools/oracle_client'
require 'tools/xml_document'

class ScopeSearch < GenericSearch
  def initialize
  end

  def query(term, index = nil, base = nil, options = {})
    OracleClient.scope_client.call('kul_packages.scope_xml_meta_file_ed', [term])
    doc = XmlDocument.open("/nas/vol03/oracle/scope01/#{term}_md.xml")
  end

end