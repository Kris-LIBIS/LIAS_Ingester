require 'cgi'
require_relative 'record/aleph_sequential'
require_relative 'record/aleph_hash'
require_relative 'record/dublin_core'
require_relative 'record/oai_pmh'
require_relative 'holding/opac_search_holding'

class Record
  FIX_FIELD_STRUCT = Struct.new(:datas)
  VAR_FIELD_STRUCT = Struct.new(:ind1, :ind2, :subfield)
  
  attr_reader :xml_document
  
  def initialize(xml_record)
    @xml_document = xml_record
    self.extend AlephSequential
    self.extend AlephHash
    self.extend DublinCore
    self.extend OaiPmh
  end 
  
  def to_raw
    @xml_document
  end
  
  def tag(t)
    tag = t[0..2]
    
    ind1 = t[3] || ''
    ind2 = t[4] || ''
    
    ind1_xpath = ind1.size > 0 ? "and @i1='#{ind1}'" : ''
    ind2_xpath = ind2.size > 0 ? "and @i2='#{ind2}'" : ''
    
    result = []
    result1 = @xml_document.root.xpath("//fixfield[@id='#{tag}']")
    result1.each do |n|
      result << FIX_FIELD_STRUCT.new(CGI::escapeHTML(n.content))
    end
    
    return result unless result.empty?
    
    query ="//varfield[@id='#{tag}' #{ind1_xpath} #{ind2_xpath}]"
    
    result2 = @xml_document.root.xpath(query)
    result2.each do |n|  
      subfields = {}
      subfields.default = ''
      n.xpath('subfield').each do |s|
#bug in XService
    	  content_array = s.content.split('$$')
        content = content_array.shift || ''
#bug in XService
        subfields[s['label']] = CGI::escapeHTML(content)
	  
	      content_array.each do |c|
          subfields[c[0]] = CGI::escapeHTML(c[1..-1])
        end
      end
        
      result << VAR_FIELD_STRUCT.new(n['i1'], n['i2'], subfields)
    end
    
    if result.empty? && tag.eql?('001')
      doc_number = xml_get_text(@xml_document.root.xpath('//doc_number'))
      result << FIX_FIELD_STRUCT.new(doc_number)
    end
    
    result
  end
  
  def holdings

    search = @xml_document.xpath('//search')
    if search
      search_type = search.first['type'].capitalize
      host = search.first['host']
      base = search.first['base']
      if search_type
        begin
          holdings_class = self.class.const_get("#{search_type}SearchHolding")
	  
          if host
            holdings_class.new(self.tag('001').first.datas, host, base)
          end
        rescue Exception
          puts "Holding class '#{search_type}SearchHolding' not found"
        end
      end
    end    
  end

end
