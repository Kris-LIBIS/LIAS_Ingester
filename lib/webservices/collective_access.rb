# coding: utf-8

require 'webservices/ca_search'
require 'webservices/ca_item_info'
require 'webservices/ca_cataloguing'

class CollectiveAccess

  attr_reader :search, :info, :cata

  def initialize(host = nil)
    @search = CaSearch.new host
    @info = CaItemInfo.new host
    @cata = CaCataloguing.new host
  end

  def authenticate(name = nil, password = nil)
    result = @search.authenticate name, password
    result &&= @info.authenticate name, password
    result && @cata.authenticate(name, password)
  end

  def deauthenticate
    @search.deauthenticate
    @info.deauthenticate
    @cata.deauthenticate
  end
  
  def add_object(label)
    @cata.add_item idno: label, type_id: 21
  end

  def search_object(attributes = {})
    query = attributes.delete :query || ''
    query = attributes.inject(query) { |q,(k,v)|
      q << ' AND ' unless q.empty?
      q << k << ':' if k
      v = "\"#{v}\"" if v.is_a?(String) and !v.include? '"'
      q << v
    }
    result = @search.query query
    return nil unless result && result.is_a?(Hash) && !result.empty?
    result.first[0]
  end

  def get_object(label)
    search_object query: "\"#{label}\""
  end

  def delete_object(object)
    @cata.remove object
  end

  def add_attribute(object, attribute, value)
    @cata.add_attribute object, attribute.to_s, {attribute.to_sym => value}
  end

  def get_attribute(object, attribute)
    result = @info.get_attribute object, attribute
    result = [result] unless result.is_a? Array
    result
  end

  def delete_attribute(_,_) #object, attribute)

  end
  
  def delete_attributes(object)
    @cata.remove_attributes object
  end

end