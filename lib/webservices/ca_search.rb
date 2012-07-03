# coding: utf-8

require_relative 'ca_connector'

class CaSearch < CaConnector

  def initialize(host = nil)
    super 'Search', host
  end

  def query(query, type = nil)
    type ||= 'ca_objects'
    request :querySoap, type: type, query: query
  end

end