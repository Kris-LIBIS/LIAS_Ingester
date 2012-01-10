# coding: utf-8

require 'tools/oracle_client'
require 'tools/xml_document'

class ScopeSearch < GenericSearch
  def initialize
  end

  def query(term, index = nil, base = nil, options = {})
    OracleClient.scope_client.call('kul_packages.scope_xml_meta_file_ed', [term.upcase])
    err_file = "/nas/vol03/oracle/scope01/#{term}_err.xml"
    if File.exist? err_file
      doc = XmlDocument.open(err_file)
      msg = doc.xpath('/error/error_msg').first.content
      msg_detail = doc.xpath('/error/error_').first.content
      File.delete(err_file);
      return nil
    end
    doc = XmlDocument.open("/nas/vol03/oracle/scope01/#{term}_md.xml")
  end

end