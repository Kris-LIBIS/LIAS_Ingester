# coding: utf-8

require 'tools/hash'
require 'tools/xml_document'

class SharepointRecord < Hash
  
  REF_MAPPER = {
      :content_type => :ows_ContentType,
      :ar_model => :ows_Access_x0020_rights_x0020_model,
      :ingest_model => :ows_Ingestmodel,
      :file_path => :ows_FileRef,
      :file_name => :ows_FileLeafRef,
      :dir_name => :ows_FileDirRef,
      :relative_path => :ows_Referentie, ## this field seems to be unreliable in the sample data
      :url => :ows_EncodedAbsUrl,
      :base_name => :ows_BaseName
  }
  
  DTL_MAPPER = {
      :label => :ows_BaseName,
      :name =>  :own_BaseName
  }

  def initialize
    super
  end

  def to_raw
    self
  end
  
  def to_xml()
    
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

    xml_doc.root = xml_doc.create_node(
        'record',
        namespaces: {
            'dc' => 'http://purl.org/dc/elements/1.1',
            'xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
            'dcterms' => 'http://purl.org/dc/terms'})
    
    self.each do |label, value|
      dc_tag = mapping.dc_tag label
      next unless dc_tag
      dc_value = (mapping.dc_prefix( label ) || '') + value + (mapping.dc_postfix( label ) || '')
      #noinspection RubyResolve
      xml_doc.root << xml_doc.create_text_node(dc_tag, dc_value)
    end
    
    xml_doc
    
  end
  
  def [](key)
    result = super
    unless result
      result = super(REF_MAPPER[key])
    end
    result
  end

=begin
  def node()
    self[:node]
  end

  def node=(n)
    self[:node] = n
  end
=end

  def relative_path()
    full_path = self[:file_path]
    return full_path.gsub(/^sites\/lias\/Gedeelde documenten\//, '') if full_path
    nil
  end

  def local_path(sub_dir)
    return relative_path unless sub_dir
    sub_dir += '/' unless sub_dir[-1] == '/'
    return relative_path.gsub(/^#{sub_dir}/, '') if relative_path
    nil
  end

  def file_name()
    self[:file_name]
  end

  def file_path()
    self[:file_path]
  end

  def url()
    self[REF_MAPPER[:url]]
  end

  def is_file?()
    return true if [:simple, :file, :mfile].include? content_type()
    false
  end

  def is_described?
    return false if ((self[:ows_Title1] and self[:ows_Title1].empty?) or self[:ows_Title1] == self[:FileLeafRef]) and
        self[:ows_Creation_x0020_date_x0020_from_x0020__x0028_approx_x002e__x0029_] and
        self[:ows_Creation_x0020_date_x0020_from_x0020__x0028_approx_x002e__x0029_].empty? and
        self[:ows_Creation_x0020_date_x0020_to_x0020__x0028_approx_x002e__x0029_] and
        self[:ows_Creation_x0020_date_x0020_to_x0020__x0028_approx_x002e__x0029_].empty? and
        self[:ows_Creation_x0020_date_x0028_s_x0029_] and
        self[:ows_Creation_x0020_date_x0028_s_x0029_].empty?
    true
  end

  def content_type()
    case self[:content_type]
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
    end
    :unknown
  end

  def content_code()
    case content_type
      when :archive
        return 'a'
      when :map
        return 'm'
      when :file
        return 'f'
      when :mmap
        return 'v'
      when :mfile
        return '<'
      when :unknown
        return '-'
    end
    ' '
  end

  def ingest_model()
    result = 'Archiveren zonder manifestations'
    if model = self[REF_MAPPER[:ingest_model]]
      case model
        when 'jpg-watermark_jp2_tn'
          result = 'Afbeeldingen hoge kwaliteit'
        when 'jpg-watermark_jpg_tn'
          result = 'Afbeeldingen lage kwaliteit'
      end
    end
    result
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
      name = mapping.name(label) || label.to_s
      if ref = REF_MAPPER.invert[label]
        name += " [#{ref.to_s}]"
      end
      f.printf " %38s : %s\n", name, value
    end

  end

end