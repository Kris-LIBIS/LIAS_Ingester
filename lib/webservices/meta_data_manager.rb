# coding: utf-8

require 'singleton'
require 'iconv'
#require 'htmlentities'

require 'webservices/soap_client'

class MetaDataManager
  include Singleton, SoapClient
  
  def initialize
    setup "MetaDataManager"
  end
  
  def create_dc( dc )
    dc_string = dc.to_s
    dc_string.force_encoding("UTF-8")
    dc_string.gsub!(/<\?xml[^\?]*\?>(\n)*/x,'')
    dc_string = '<?xml version="1.0" encoding="UTF-8"?>' + dc_string
#    dc_string.gsub!('&','&amp;')
#    dc_string.gsub!('<', '&lt;')
#    dc_string = HTMLEntities.new.encode(dc_string, :named)
    request :create_meta_data_entry, :general => general.to_s, :description => nil, :name => 'descriptive', :type => 'dc', :value => dc_string
  end
  
  def create_dc_from_xml( xml_doc )
    create_dc_record_from_xml xml_doc
  end
  
  def update_dc( mid, dc )
    request :update_meta_data_entry, :mid => mid.to_s, :general => general.to_s, :description => nil, :name => 'descriptive', :type => 'dc', :value => dc.to_s
  end
  
  def create_acl( acl )
    request :create_meta_data_entry, :general => general.to_s, :description => nil, :name => 'accessrights', :type => 'rights_md', :value => acl.to_s
  end
  
  def update_acl( mid, acl )
    request :update_meta_data_entry, :mid => mid.to_s, :general => general.to_s, :description => nil, :name => 'accessrights', :type => 'rights_md', :value => acl.to_s
  end
  
  def delete( mid )
    request :delete_meta_data_entry, :mid => mid.to_s, :general => general.to_s
  end
  
  def retrieve( mid )
    request :retrieve_meta_data_entry, :mid => mid.to_s, :general => general.to_s
  end
  
  def create_dc_record_from_xml(xml_doc)
    doc = XmlDocument.open xml_doc
    records = doc.xpath('/records/record')
    return nil unless records.size > 0
    create_dc(records[0])
  end
  
  def create_dc_record(dc_info)
    doc = XmlDocument.new
    doc.root = doc.create_node('record',
                               :namespaces => { 'dc' => 'http://purl.org/dc/elements/1.1',
                                                'dcterms' => 'http://purl.org/dc/terms',
                                                'xsi' => 'http://www.w3.org/2001/XMLSchema-instance'})
    if dc_info
      dc_info.each do |k,v|
        doc.root << (n = doc.create_text_node(k.to_s, v.to_s))
        n['xsi:type'] = 'dcterms:URI' if v =~ /^http:\/\//
      end
    end
    doc
  end
  
  def create_acl_record(acl_info = nil)
    doc = XmlDocument.new
    doc.root = doc.create_node('access_right_md',
                               :namespaces => { :node_ns  => 'ar',
                                                'ar'      => 'http://com/exlibris/digitool/repository/api/xmlbeans',
                                                'xs'      => 'http://www.w3.org/2001/XMLSchema'})
    root = doc.root
    root['enabled'] = 'true'
    return doc unless acl_info
    if (c = acl_info[:copyright])
      add_acl_copyright(doc, c[:text_file], c[:required])
    end
    if (e = acl_info[:conditions])
      e.each do |x|
        add_acl_condition(doc, x[:expressions], x[:negate])
      end
    end
    doc
  end
  
  def add_acl_copyright(doc, text_file, required = true)
    root = doc.root
    top = root.xpath('ar_copyrigths')
    if top.empty?
      top = doc.create_node('ar_copyrights')
      root << top
    else
      top = top[0]
    end
    top['required'] = required.to_s if required
    child = top.xpath('text_file')
    child = child.empty? ? doc.create_node('text_file') : top[0]
    child.content = text_file
    top << child
    doc
  end
  
  def add_acl_user_group_ip(doc, user, group, iprange, negate = false)
    expressions = []
    user.split.each {|u| expressions << create_acl_expression_user(u)} if user
    group.split.each {|g| expressions << create_acl_expression_group(g)} if group
    iprange.split.each {|i| expressions << create_acl_expression_iprange(i)} if iprange
    add_acl_condition doc, expressions, negate
  end
  
  def add_acl_user(doc, user, negate = false)
    expressions = Array.new
    user.split.each {|u| expressions << create_acl_expression_user(u, negate)}
    add_acl_condition doc, expressions
  end
  
  def add_acl_group(doc, group, negate = false)
    expressions = Array.new
    group.split.each {|g| expressions << create_acl_expression_group(g, negate)}
    add_acl_condition doc, expressions
  end
  
  def add_acl_iprange(doc, iprange, negate = false)
    expressions = Array.new
    iprange.split.each {|i| expressions << create_acl_expression_iprange(i, negate)}
    add_acl_condition doc, expressions
  end
  
  def add_acl_condition(doc, expressions, negate = false)
    root = doc.root
    top = root.xpath('ar_conditions')
    if (top.empty?)
      top = doc.create_node('ar_conditions')
      root << top
    else
      top = top[0]
    end
    top << (cond_node = doc.create_node('ar_condition'))
    cond_node['negate'] = negate.to_s if negate
    cond_node << (exprs_node = doc.create_node('ar_expressions'))
    expressions.each do |e|
      exprs_node << (expr_node = doc.create_node('ar_expression'))
      expr_node['negate'] = e[:negate].to_s if e[:negate]
      expr_node['ar_operation'] = e[:operation].to_s if e[:operation]
      expr_node << doc.create_text_node('key', e[:key].to_s)
      expr_node << doc.create_text_node('val1', e[:val1].to_s)
      expr_node << doc.create_text_node('val2', e[:val2].to_s) if e[:val2]
    end
    doc
  end
  
  def create_acl_expression_user(user, negate = false)
    { :operation  => 'eq',
      :negate     => negate.to_s,
      :key        => 'user_id',
      :val1       => user.to_s
    }
  end
  
  def create_acl_expression_group(group, negate = false)
    { :operation  => 'eq',
      :negate     => negate.to_s,
      :key        => 'group_id',
      :val1       => group.to_s
    }
  end
  
  def create_acl_expression_iprange(iprange, negate = false)
    return nil unless iprange =~ /(\d+\.\d+\.\d+\.\d+)-(\d+\.\d+\.\d+\.\d+)/
    { :operation  => 'within',
      :negate     => negate.to_s,
      :key        => 'ip_range',
      :val1       => $1,
      :val2       => $2
    }
  end
  
end
