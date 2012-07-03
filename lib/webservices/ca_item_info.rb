# coding: utf-8

require_relative 'ca_connector'

class CaItemInfo < CaConnector

  def initialize(host = nil)
    super 'ItemInfo', host
  end

  def get_attributes(item, type = nil)
    type ||= 'ca_objects'
    request :getAttributes, type: type, item_id: item.to_s
  end

  def get_attribute(item, attribute, type = nil)
    type ||= 'ca_objects'
    request :getAttributesByElement, type: type, item_id: item.to_s, attribute_code_or_id: attribute.to_s
  end

  def get_items(item_list, bundle, type = nil)
    type ||= 'ca_objects'
    r1, a1 = soap_encode item_list
    r2, a2 = soap_encode bundle
    request :get, type: type, item_ids: r1, bundles: r2, :attributes! => { item_ids: a1, bundles: a2 }
  end

end