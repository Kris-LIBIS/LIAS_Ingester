#require 'soap/wsdlDriver'
require 'savon'
require 'lib/tools/xml_writer'

class SoapClient
  include XmlWriter

  attr_reader :client

  def initialize( service )
    Savon.configure do |cfg|
      cfg.logger = Application.instance.logger
      cfg.log_level = ConfigFile['SOAP_logging_level'] || :error
      cfg.log = ConfigFile['SOAP_logging']
      cfg.soap_version = 2
      cfg.raise_errors = false
      HTTPI.logger = Application.instance.logger
      HTTPI.log_level = ConfigFile['SOAP_logging_level'] || :error
      HTTPI.log = ConfigFile['SOAP_logging']
    end
    @client = Savon::Client.new do
      http.read_timeout = 120
      http.open_timeout = 120
      wsdl.document = "http://aleph08.libis.kuleuven.be:1801/de_repository_web/services/" + service + "?wsdl"
    end
  end
  
  def request( method, body)
    b = body.clone; b.delete(:general)
    @@logger.debug(self.class) { "Request '#{method.inspect}' '#{b.inspect}'"}
    response = @client.request method do |soap|
      soap.body = body
    end
    parse_result response
  end

  def parse_result( response )
    error = []
    pids = []
    mids = []
    de = []
    r = response.to_hash
    unless response.success?
      error << "SOAP Fault: " + response.soap_fault.to_s if response.soap_fault?
      error << "HTTP Error: " + response.http_error.to_s if response.http_error?
    else
#      @@logger.debug(self.class) { "Response: '#{r.to_s.inspect}'"}
      result = get_xml_response(r)
#      @@logger.debug(self.class) { "Result: '#{result.inspect}'"}
      doc = Nokogiri::XML(result)
      doc.xpath('//error_description').each { |x| error << x.content unless x.content.nil? }
      doc.xpath('//pid').each { |x| pids << x.content unless x.content.nil?}
      doc.xpath('//mid').each { |x| mids << x.content unless x.content.nil?}
      doc.xpath('//xb:digital_entity').each { |x| de << x.to_s }
    end
    @@logger.debug(self.class) { "Result: error='#{error.inspect}', pids='#{pids.inspect}', mids='#{mids.inspect}', digital_entities='#{de.inspect}'"}
    { :error => error, :pids => pids, :mids => mids, :digital_entities => de, :result => r}
  end

  def general( owner = 'LIA01', user = 'super:lia01', password = 'super' )
    doc = create_document
    root = create_node('general')
    add_namespaces(root, {
      :node_ns   => 'xb',
      'xb'       => 'http://com/exlibris/digitool/repository/api/xmlbeans'})
    doc.root = root
    root << create_text_node('application', 'DIGITOOL-3')
    root << create_text_node('owner', owner)
    root << create_text_node('interface_version', '1.0')
    root << create_text_node('user', user)
    root << create_text_node('password', password)
    return doc
  end
  
  def get_xml_response( response )
    return response.first[1][response.first[1][:result].to_s.gsub(/\B[A-Z]+/, '_\&').downcase.to_sym]
  end

end

