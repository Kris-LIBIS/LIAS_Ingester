require 'xml'

module XmlWriter

  private
  
  def create_document( encoding = XML::Encoding::UTF_8 )

    document = XML::Document.new
    document.encoding = encoding

    return document

  end

  def create_text_node( name, text, options = nil )
    node = create_node name, options
    node << text
    node
  end

  def create_node( name, options = nil )

    node = XML::Node.new name

    return node unless options

    namespaces = options.delete :namespaces
    add_namespaces( node, namespaces ) if namespaces

    attributes = options.delete :attributes
    add_attributes( node, attributes ) if attributes

    return node

  end

  def add_namespaces( node, namespaces )

    node_ns = namespaces.delete :node_ns

    namespaces.each do |prefix, prefix_uri|
      XML::Namespace.new node, prefix, prefix_uri
    end

    node.namespaces.namespace = node.namespaces.find_by_prefix(node_ns) if node_ns

    return node

  end

  def add_attributes( node, attributes )

    attributes.each do |name, value|
      XML::Attr.new node, name, value
    end

    return node

  end

end

