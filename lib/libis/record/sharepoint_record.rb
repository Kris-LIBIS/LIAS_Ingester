# coding: utf-8

require 'uri'

require 'ingester_task'
require 'tools/hash'
require 'tools/xml_document'

class SharepointRecord < Hash
  include IngesterTask

  attr_accessor :node
  
  def initialize
    @node = nil
    self[:label_prefix] = ''
    super nil
  end

  def label_prefix
    self[:label_prefix]
  end

  def label_prefix=(value)
    self[:label_prefix] = value
  end

  def label
    (self[:ows_Title1] || self[:ows_BaseName] || file_name).to_s
  end

  def title
    self[:label_prefix] + ' ' + self.label
  end

  def content_type
    self[:ows_ContentType]
  end

  def file_name
    self[:ows_FileLeafRef]
  end

  def file_path
    self[:ows_FileRef]
  end

  def file_size
    self[:ows_FileSizeDisplay]
  end

  def url
#    self[:ows_EncodedAbsUrl]
#    'https://www.groupware.kuleuven.be' + URI.escape(self[:ows_ServerUrl], Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
#    'https://www.groupware.kuleuven.be' + URI.escape(self[:ows_ServerUrl])
    URI.escape(URI.unescape(self[:ows_EncodedAbsUrl]))
  end

  def relative_path
    return file_path.gsub(/^sites\/lias\/Gedeelde documenten\//, '') if file_path
    nil
  end

  def local_path(sub_dir)
    return relative_path unless sub_dir
    sub_dir += '/' unless sub_dir[-1] == '/'
    return relative_path.gsub(/^#{sub_dir}/, '') if relative_path
    nil
  end

  def is_file?
    return true if [:file, :mfile].include? simple_content_type
    false
  end

  def is_described?
=begin
    self[:ows_Title1] and
        (   self[:ows_Creation_x0020_date_x0028_s_x0029_] or
            self[:ows_Startdate] or
            self[:ows_Enddate]
        )
=end
    self[:ows_Unit_of_description]
  end

  def simple_content_type
    case content_type
      when /^Archief/i
        return :archive
      when /^Bestanddeel \(folder\)/i
        return :map
      when /^Bestanddeel of stuk \(document\)/i
        return :file
      when /^Meervoudige beschrijving \(folder\)/i
        return :mmap
      when /^Meervoudige beschrijving \(document\)/i
        return :mfile
      when /^Tussenniveau/i
        return :map
      when /^Film/i
        return :file
      when /^Object/i
        return :file
      when /^Document/i
        return :file
      else
        # type code here
    end
    :unknown
  end

  def content_code
    case simple_content_type
      when :archive
        'a'
      when :map
        'm'
      when :file
        'f'
      when :mmap
        'v'
      when :mfile
        '<'
      when :unknown
        '-'
      else
        ' '
    end + (is_described? ? '*' : ' ')
  end

  def ingest_model
    return self[:ows_Ingestmodel] if self[:ows_Ingestmodel]
    return self.node.parent.content.ingest_model if node and node.parent and node.parent.content
    nil
  end

  def accessright_model
    return self[:ows_Access_x0020_rights_x0020_model] if self[:ows_Access_x0020_rights_x0020_model]
    return self.node.parent.content.accessright_model if node and node.parent and node.parent.content
    nil
  end

  def to_raw
    self
  end
  
  def to_xml
    
    xml_doc = XmlDocument.new

    xml_doc.root = xml_doc.create_node('record')
    
    self.each do |label, value|

      unless label == :node
        #noinspection RubyResolve
        xml_doc.root << xml_doc.create_text_node(label.to_s, value.to_s)
      end
      
    end
    
    xml_doc
    
  end
  
  def self.from_xml(xml_node)
    
    record = SharepointRecord.new
    
    xml_node.element_children.each do | node |
      record[node.name.to_sym] = node.content
    end
    
    record
    
  end
  
  def to_dc(  mapping )
    
    return nil unless mapping and mapping.is_a? Hash
    
    xml_doc = XmlDocument.new

    #noinspection RubyStringKeysInHashInspection
    xml_doc.root = xml_doc.create_node(
        'record',
        namespaces: {
            'dc' => 'http://purl.org/dc/elements/1.1/',
            'xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
            'dcterms' => 'http://purl.org/dc/terms/'})
    
    self.each do |label, value|
      dc_tag = mapping.dc_tag(label)
      next unless dc_tag
      dc_value = (mapping.dc_prefix( label ) || '') + value.to_s + (mapping.dc_postfix( label ) || '')
      #noinspection RubyResolve
      xml_doc.root << xml_doc.create_text_node(dc_tag, dc_value)
    end

    if xml_doc.xpath('//dc:title').size == 0
      xml_doc.root << xml_doc.create_text_node('dc:title', self[:ows_BaseName])
    end
    
    xml_doc
    
  end

  def to_sql( mapping )
    sql_fields = []
    sql_values = []

    self.each do |label, value|
      db_column = mapping.db_column(label)
      next unless db_column
      db_value = mapping.db_value(label,value)
      next unless db_value and db_value != "''"
      sql_fields << db_column
      sql_values << db_value.escape_for_sql
    end

    sql_fields.each_with_index { | element, index | (index % 10 == 0) && (sql_fields[index] = "\n    " + element)
    }
    sql_values.each_with_index { | element, index | (index % 10 == 0) && (sql_values[index] = "\n    " + element)
    }

    'INSERT INTO @TABLE_NAME@ (' + sql_fields.join(',') + ")\n  VALUES (" + sql_values.join(',') + ');'

  end
  
  def create_dc(dir, mapping)
    xml_doc = to_dc mapping
    dc_file = "#{dir}/dc_#{self[:index].to_s}.xml"
    xml_doc.save dc_file
    dc_file
  end

  def to_s
    super
  end

  def print_metadata(f, mapping)
    f.printf "%6d -------------------------------------------------------------------------\n", self[:index].to_i
    self.each do |label, value|
      next if label == :node
#      next if label == :index
      name = mapping.fancy_label(label)
      f.printf " %40s : %s\n", name, value
    end

  end

end
