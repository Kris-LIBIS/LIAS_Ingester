# coding: utf-8

require_relative 'ca_connector'

class CaCataloguing < CaConnector

  def initialize(host = nil)
    super 'Cataloguing', host
  end

  def add_item(fields, type = nil)
    type ||= 'ca_objects'
    r,a = soap_encode fields
    request :add, type: type, fieldInfo: r, :attributes! => {fieldInfo: a}
  end

  def add_attributes(item, data, type = nil)
    type ||= 'ca_objects'
    r,a = soap_encode data
    request :getAttributesByElement, type: type, item_id: item, attribute_code_or_id: attribute.to_s, attribute_list_array: r, :attributes! => {attribute_list_array: a}

  end

  def add_attribute(item, attribute, data, type = nil)
    type ||= 'ca_objects'
    r,a = soap_encode data
    request :addAttribute, type: type, item_id: item, attribute_code_or_id: attribute.to_s, attribute_data_array: r, :attributes! => {attribute_data_array: a}
  end

  def remove(item, type = nil)
    type ||= 'ca_objects'
    request :remove, type: type, item_id: item
  end

  def remove_attributes(item, type = nil)
    type ||= 'ca_objects'
    request :removeAllAttributes, type: type, item_id: item
  end

end