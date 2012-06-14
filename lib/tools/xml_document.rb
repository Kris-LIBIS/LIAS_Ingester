# coding: utf-8

require 'nokogiri'

#noinspection RubyResolve
class XmlDocument

  attr_accessor :document

  def invalid?
    @document.nil? or @document.root.nil?
  end

  def valid?
    ! invalid?
  end

  def initialize( encoding = 'utf-8')
    @document = Nokogiri::XML::Document.new
    @document.encoding = encoding
  end

  def self.open( file )
    doc = XmlDocument.new
    doc.document = Nokogiri::XML(File.open(file))
    doc
  end

  def self.parse( xml )
    doc = XmlDocument.new
    doc.document = Nokogiri::parse(xml)
    doc
  end

  def save( file, indent = 2, encoding = 'utf-8' )
    fd = File.open(file, "w")
    @document.write_xml_to(fd, :indent => indent, :encoding => encoding)
    fd.close
  end

  def to_xml( options = {} )
    options = { indent: 2, encoding: 'utf-8' }.merge(options)
    @document.to_xml(options)
  end

  def validates_against?(schema)
    schema_doc = Nokogiri::XML::Schema.new(File.open(schema))
    schema_doc.valid?(@document)
  end

  def add_processing_instruction( name, content )
    processing_instruction = Nokogiri::XML::ProcessingInstruction.new( @document, name, content )
    @document.root.add_previous_sibling processing_instruction
    processing_instruction
  end

  def build( at_node = nil, &block )
    if at_node
      Nokogiri::XML::Builder.with(at_node, &block)
    else
      xml = Nokogiri::XML::Builder.new(&block)
      @document = xml.doc
    end
    self
  end

  def create_text_node( name, text, options = {} )
    node = create_node name, options
    node << text
    node
  end

  def create_node( name, options = {} )

    node = Nokogiri::XML::Node.new name, @document

    return node if options.empty?

    namespaces = options.delete :namespaces
    add_namespaces( node, namespaces ) if namespaces

    attributes = options.delete :attributes
    add_attributes( node, attributes ) if attributes

    node

  end

  def add_namespaces( node, namespaces )
    XmlDocument.add_namespaces node, namespaces
  end

  def self.add_namespaces( node, namespaces )

    node_ns = namespaces.delete :node_ns

    namespaces.each do |prefix, prefix_uri|
      node.add_namespace prefix, prefix_uri
    end

    node.name = node_ns + ':' + node.name if node_ns

    node

  end

  def add_attributes( node, attributes )
    XmlDocument.add_attributes node, attributes
  end

  def self.add_attributes( node, attributes )

    attributes.each do |name, value|
      node.set_attribute name.to_s, value
    end

    node

  end

  def root=( node )
    raise ArgumentError, "XML document not valid." if @document.nil?
    #noinspection RubyArgCount
    @document.root = node
  end

  def root
    raise ArgumentError, "XML document not valid." if @document.nil?
    @document.root
  end

  def xpath(path)
    raise ArgumentError, "XML document not valid." if self.invalid?
    @document.xpath(path)
  end

  def has_element?(element_name)
    list = xpath("//#{element_name}")
    list.nil? ? 0 : list.size()
  end

  def self.get_content(nodelist)
    (nodelist.first && nodelist.first.content) || ''
  end

end
