require 'rubygems'
require 'nokogiri'
require_relative 'generic_search'
require 'pp'
require_relative '../../tools/hash'

class OpacSearch < GenericSearch
 # attr_reader :xml_document
  
  def query(term, index, base, options = {})
    raise ArgumentError, 'options must be a hash' unless options.is_a?(Hash)
    
    options.key_symbols_to_strings!

    @host           = options['host'] if options.include?('host')
    @term           = term
    @index          = index
    @base           = base
    @record_pointer = 1
    @num_records    = 0
    @session_id     = 0
    @set_number     = 0    
    
    response = execute_http_query("op=find&code=#{@index}&request=#{@term}&base=#{@base}")
    if response
      @set_number = xml_get_text(response.xpath('//find/set_number'))
      @num_records = xml_get_text(response.xpath('//find/no_records')).to_i
      @session_id = xml_get_text(response.xpath('//find/session-id'))    
    end
    
  end

  def each(set_number = nil)
    if !set_number.nil? && @set_number != set_number
      @record_pointer = 1
      @set_number = set_number
    elsif @set_number.nil?
      return
    end

    while @record_pointer <= @num_records

      if @record_pointer <= @num_records        
        response = execute_http_query("op=present&set_entry=#{@record_pointer}&set_number=#{@set_number}&base=#{@base}")
        
        if response
          response.root << element = Nokogiri::XML::Node.new('search', response)
          element['type'] = 'opac'
          element['host'] = @host
          element['base'] = @base
          set_entry  = xml_get_text(response.root.xpath('//set_entry')).to_i
          if set_entry == @record_pointer
            add_item_data(response)
            yield response
          end             
        end   
      else
        puts 'no record found'
      end
      
      @record_pointer += 1
    end
  end


private

  def str_to_xml(str)
    error = ''
    xml_document = Nokogiri::XML(str)

    if xml_document
      error = xml_get_text(xml_document.xpath('//error'))
    end

    return xml_document, error
  end

  def xml_get_text(xpath)
    text = ''
    if xpath.size == 1
      text = xpath.first.content
    end

    text
  end

  
  def add_item_data(xml_document)
    
    doc_number = xml_get_text(xml_document.root.xpath('//doc_number'))
    response = execute_http_query("op=item-data&base=#{@base}&doc-number=#{doc_number}")
    
    if response
      oai_marc = xml_document.root.xpath('//oai_marc').first
      
      response.root.xpath('//item').each do |r| 
        collection     = r.xpath('//collection').first.content
        location       = r.xpath('//sub-library').first.content
        classification = r.xpath('//call-no-1').first.content
        
         varfield = Nokogiri::XML::Node.new('varfield', xml_document)
         varfield['id'] = '852'
         varfield['i1'] = ' '
         varfield['i2'] = ' '
         
         subfield_b = Nokogiri::XML::Node.new('subfield', xml_document)
         subfield_b['label'] = 'b'
         subfield_b.content = collection

         subfield_c = Nokogiri::XML::Node.new('subfield', xml_document)
         subfield_c['label'] = 'c'
         subfield_c.content = location

         subfield_h = Nokogiri::XML::Node.new('subfield', xml_document)
         subfield_h['label'] = 'h'
         subfield_h.content = classification.gsub('$$h', '')
                  
         varfield << subfield_b
         varfield << subfield_c
         varfield << subfield_h
         
         oai_marc << varfield                  
      end      
    end  
  end


  def execute_http_query(data)
    if @host.nil? || @host.size == 0
      raise Exception, "No host set"
    end

    begin
      xml_document = nil
      redo_search = false
      redo_count = 10
      begin
        redo_count = redo_count - 1
        sleep_time = 0.1 # in minutes
        
        response = Net::HTTP.fetch(@host, :data => data, :action => :post)
   
      if response.is_a?(Net::HTTPOK)
        xml_document, error = str_to_xml(response.body)
        if xml_document && error.size == 0
          #puts " Found #{xml_get_text(xml_document.xpath('//find/no_records'))} records"
          nil
        else
          puts
          puts "----------> Error searching for #{@term} --> '#{error}'"
          puts
          if error =~ /license/
            redo_search = true
          end          
        end
      else
        puts response.error!
      end
      rescue Exception => ex
        sleep_time = 2
        if ex.message =~ /503 "Service Temporarily Unavailable"/
          sleep_time = 30
          Application.warn('OPAC_Search') {"OPAC Service temporarily unavailable - retrying after #{sleep_time} minutes"}
        else
          Application.error('OPAC_Search') {"Problem with OPAC: '#{ex.message}' - retrying after #{sleep_time} minutes"}
        end
        redo_search = true
      end
        
      sleep sleep_time * 60 if redo_search
      
    end until redo_search == false or redo_count < 0
    
    xml_document
  end

  
end
