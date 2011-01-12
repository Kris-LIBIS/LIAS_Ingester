require 'cgi'
require 'lib/tools/string'
require File.dirname(__FILE__) + '/record/aleph_sequential'
require File.dirname(__FILE__) + '/record/aleph_hash'
require File.dirname(__FILE__) + '/record/dublin_core'
require File.dirname(__FILE__) + '/record/oai_pmh'
require File.dirname(__FILE__) + '/holding/opac_search_holding'

class Record
  FixFieldStruct = Struct.new(:datas)
  VarFieldStruct = Struct.new(:ind1, :ind2, :subfield)  
  
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

    ind1 = (t[3].chr if t.size > 3) || ''
    ind2 = (t[4].chr if t.size > 4) || ''
    
    ind1_xpath = ind1.size > 0 ? "and @i1='#{ind1}'" : ''
    ind2_xpath = ind2.size > 0 ? "and @i2='#{ind2}'" : ''
    
    result = []
    result1 = @xml_document.root.find("//fixfield[@id='#{tag}']")
    if result1.size > 0
      result1.each do |n|
        result << FixFieldStruct.new(CGI::escapeHTML(n.content))
      end
    end

    return result if result1.size > 0
    query ="//varfield[@id='#{tag}' #{ind1_xpath} #{ind2_xpath}]"

    result2 = @xml_document.root.find(query)    
    if result2.size > 0
      result2.each do |n|       
        subfields = {}
        subfields.default = ''
        n.find('subfield').each do |s|          
#bug in XService
	  content_array = s.content.split('$$') 
	  content = content_array.shift || ''
#bug in XService
          subfields.store(s.attributes['label'], CGI::escapeHTML(content))

	  content_array.each do |c|
             subfields.store(c[0], CGI::escapeHTML(c[1..c.length]))
          end
        end
        
        result << VarFieldStruct.new(n.attributes['i1'], n.attributes['i2'], subfields)
      end
    end

    if result.empty? && tag.eql?('001')
      doc_number = xml_get_text(@xml_document.root.find('//doc_number'))
      result << FixFieldStruct.new(doc_number)
    end
    
    return result
  end
  
  def holdings     
    holding_data = []
    search = @xml_document.find('//search')
    if search
      search_type = search.first['type'].capitalize    
      host = search.first['host']
      base = search.first['base']
      if search_type
        begin
          holdings_class = self.class.const_get("#{search_type}SearchHolding")
        
          if host
            holding_data = holdings_class.new(self.tag('001').first.datas, host, base)
          end
        rescue Exception => e
          puts "Holding class '#{search_type}SearchHolding' not found"
        end
      end
    end    
  end    
end
