#require 'soap/wsdlDriver'
require 'savon'
require 'lib/tools/xml_writer'
require 'htmlentities'

class SoapClient
  include XmlWriter

  attr_reader :client

  def initialize( service )
    Savon::Request.log = false
    url = "http://aleph08.libis.kuleuven.be:1801/de_repository_web/services/" + service + "?wsdl"
    @client = Savon::Client.new(url)
  end

  def parse_result( result )
    d = XML::Document.string(result.to_xml)
    coder = HTMLEntities.new
    r = coder.decode(d.root.child.child.content)
    doc = XML::Document.string(r)
    error = []
    error << result.soap_fault if result.soap_fault?
    error << result.http_error if result.http_error?
    doc.find('//error_description').each { |x| error << x.content unless x.content.nil? }
    pids = []
    doc.find('//pid').each { |x| pids << x.content unless x.content.nil?}
    mids = []
    doc.find('//mid').each { |x| mids << x.content unless x.content.nil?}
    de = []
    doc.find('//xb:digital_entity').each { |x| de << x.to_s }
    { :error => error, :pids => pids, :mids => mids, :digital_entities => de, :result => r}
  end

  def general( owner = 'LIA01', user = 'super:lia01', password = 'super' )
    doc = create_document
    root = create_node('general')
    add_namespaces(root, {
      :node_ns   => 'xb',
      'xb'       => 'http://com/exlibris/digitool/repository/api/xmlbeans'})
    doc.root = root
    root << (create_node('application') << 'DIGITOOL-3')
    root << (create_node('owner') << owner)
    root << (create_node('interface_version') << '1.0')
    root << (create_node('user') << user)
    root << (create_node('password') << password)
    return doc
  end

end

