require 'nokogiri'

module XmlWriter

  private
  
  def create_document( encoding = 'utf-8' )
    
    @document = Nokogiri::XML::Document.new
    @document.encoding = encoding
    
    @document
    
  end
  
  def save_document( document, file, indent = 2, encoding = 'utf-8')
    fd = File.open(file, 'w')
    document.write_xml_to(fd, :indent => indent, :encoding => encoding)
    fd.close
  end

  def create_text_node( name, text, options = nil )
    node = create_node name, options
    node << text
    node
  end

  def create_node( name, options = nil )

    node = Nokogiri::XML::Node.new name, @document

    return node unless options

    namespaces = options.delete :namespaces
    add_namespaces( node, namespaces ) if namespaces

    attributes = options.delete :attributes
    add_attributes( node, attributes ) if attributes

    node

  end

  def add_namespaces( node, namespaces )

    node_ns = namespaces.delete :node_ns

    namespaces.each do |prefix, prefix_uri|
      node.add_namespace prefix, prefix_uri
    end

    node.name = node_ns + ':' + node.name if node_ns

    node

  end

  def add_attributes( node, attributes )

    attributes.each do |name, value|
      node.set_attribute name, value
    end

    node

  end

end

