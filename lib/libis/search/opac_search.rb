require 'rubygems'
require 'xml/libxml'
require 'libis/search/generic_search'
require 'pp'
require 'tools/hash'

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
      @set_number = xml_get_text(response.find('//find/set_number'))
      @num_records = xml_get_text(response.find('//find/no_records')).to_i
      @session_id = xml_get_text(response.find('//find/session-id'))    
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
      set_entry  = 0
      doc_number = 0
      oai_marc   = nil
      record     = nil
      
      if @record_pointer <= @num_records        
        response = execute_http_query("op=present&set_entry=#{@record_pointer}&set_number=#{@set_number}&base=#{@base}")
        
        if response
          response.root << element = XML::Node.new('search')
          element['type'] = 'opac'
          element['host'] = @host
          element['base'] = @base
          set_entry  = xml_get_text(response.root.find('//set_entry')).to_i
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
    xml_parser = XML::Parser.string(str)
    xml_document  = xml_parser.parse

    if xml_document
      error = xml_get_text(xml_document.find('//error'))
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
    
    doc_number = xml_get_text(xml_document.root.find('//doc_number'))
    response = execute_http_query("op=item-data&base=#{@base}&doc-number=#{doc_number}")
    
    if response
      oai_marc = xml_document.root.find('//oai_marc').first
      
      response.root.find('//item').each do |r| 
        collection     = r.find('//collection').first.content
        location       = r.find('//sub-library').first.content
        classification = r.find('//call-no-1').first.content
        
         varfield = XML::Node.new('varfield')
         varfield['id'] = '852'
         varfield['i1'] = ' '
         varfield['i2'] = ' '
         
         subfield_b = XML::Node.new('subfield')
         subfield_b['label'] = 'b'
         subfield_b.content = collection

         subfield_c = XML::Node.new('subfield')
         subfield_c['label'] = 'c'
         subfield_c.content = location

         subfield_h = XML::Node.new('subfield')
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
      return
    end

    begin
      xml_document = nil
      redo_search = false
      response = Net::HTTP.fetch(@host, :data => data, :action => :post)
    
      if response.is_a?(Net::HTTPOK)
        xml_document, error = str_to_xml(response.body)
        if xml_document && error.size == 0
          #puts " Found #{xml_get_text(xml_document.find('//find/no_records'))} records"
          nil
        else
          puts
          puts "----------> Error searching for #{@term} --> '#{error}'"
          puts
          if error =~ /license/
            redo_search = true
            sleep 5
          end          
        end
      else
        puts response.error!
      end
    end until redo_search == false
    
    return xml_document
  end

  
end
