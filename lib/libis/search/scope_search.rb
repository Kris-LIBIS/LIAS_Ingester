# coding: utf-8

require 'tools/oracle_client'
require 'tools/xml_document'

class ScopeSearch < GenericSearch
  def initialize
    @doc = nil
  end

  def query(term, _ = nil, _ = nil, _ = {})
    OracleClient.scope_client.call('kul_packages.scope_xml_meta_file_ed', [term.upcase])
    err_file = "/nas/vol03/oracle/scope01/#{term}_err.XML"
    if File.exist? err_file
      doc = XmlDocument.open(err_file)
      msg = doc.xpath('/error/error_msg').first.content
      msg_detail = doc.xpath('/error/error_').first.content
      File.delete(err_file)
      Application.error('ScopeSearch') {"Scope search failed: '#{msg}'. Details: '#{msg_detail}'"}
      @doc = nil
    else
      @doc = XmlDocument.open("/nas/vol03/oracle/scope01/#{term}_md.XML")
    end
  end

  def each
    yield @doc
  end

  def next_record
    yield @doc
  end

end