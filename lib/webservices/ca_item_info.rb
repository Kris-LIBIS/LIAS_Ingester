# coding: utf-8

require_relative 'ca_connector'

class CaItemInfo < CaConnector

  def initialize
    super 'ItemInfo'
  end

  def attributes(item, type = nil)
    type ||= 'ca_objects'
    request :getAttributes, type: type, item_id: item.to_s
  end

  def attribute(item, attribute, type = nil)
    type ||= 'ca_objects'
    request :getAttributesByElement, type: type, item_id: item.to_s, attribute_code_or_id: attribute.to_s
  end

end