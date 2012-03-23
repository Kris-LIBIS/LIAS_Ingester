# coding: utf-8

require 'savon'
require 'nori'
require 'net/https'

require 'tools/xml_document'

module SoapClient

  def init
    @base_url = 'http://aleph08.libis.kuleuven.be:1801/de_repository_web/services/'
    @wsdl_extension = '?wsdl'
    # Disabled the use of Nokogiri parser. It aborts when illegal characters are encountered, while the default REXML
    # does not care. Unfortunately SharePoint web services will send XML with illegal characters when they exist in
    # the document's metadata.
    # Nori.parser = :nokogiri
    Nori.configure do |config|
      config.convert_tags_to do |tag|
        tag =~ /(^@ows_)|(^Etag$)/ ?
            tag.gsub(/^@/,'').to_sym :
            tag.snakecase.to_sym
      end
    end
    Nori.strip_namespaces = true
  end

  #noinspection RubyResolve
  attr_reader :client

  def setup( service, options = {} )
    init unless @base_url
    Savon.configure do |cfg|
      cfg.logger = Application.instance.logger
      cfg.log_level = ConfigFile['SOAP_logging_level'] || :info
      cfg.log = ConfigFile['SOAP_logging']
      cfg.soap_version = 2
      cfg.raise_errors = false
      HTTPI.logger = Application.instance.logger
      HTTPI.log_level = ConfigFile['SOAP_logging_level'] || :info
      HTTPI.log = ConfigFile['SOAP_logging']
    end

    url = options[:wsdl_url] || @base_url + service + @wsdl_extension
    proxy = options[:proxy]

    @client = Savon::Client.new do |wsdl, http|
      if options[:ssl]
        http.auth.ssl.verify_mode = :none
#        http.auth.ssl.ca_cert_file = Application.dir + '/config/cacert.pem'
#        url = File.expand_path(Application.dir + '/config/sharepoint/' + service, __FILE__)
      end
      http.read_timeout = 120
      http.open_timeout = 120
      wsdl.document = url
      wsdl.element_form_default = :unqualified
      http.proxy = proxy if proxy
      if options[:username] and options[:password]
        http.auth.basic options[:username], options[:password]
      end
    end

    @client
  end
  
  def request( method, body)
    b = body.clone; b.delete(:general)
    soap_options = body.delete(:soap_options) || {}
    wsdl_options = body.delete(:wsdl_options) || {}
    http_options = body.delete(:http_options) || {}
    wsse_options = body.delete(:wsse_options) || {}
    method_options = body.delete(:method_options) || {}
    Application.instance.logger.debug(self.class) { "Request '#{method.inspect}' '#{b.inspect}'"}
    response = @client.request method, method_options do |soap, wsdl, http, _|
      soap.body = body
      soap.used_namespaces
      soap_options.each do |k, v|
        soap.send (k.to_s + '=').to_sym, v
      end
      wsdl_options.each do |k, v|
        wsdl.send (k.to_s + '=').to_sym, v
      end
      http_options.each do |k, v|
        http.send (k.to_s + '=').to_sym, v
      end
      if wsse_options[:username]
        http.auth.basic wsse_options[:username], wsse_options[:password]
      end
    end
    result = parse_result response
    result
  end

  def parse_result( response )
    unless response.success?
      error = []
      error << "SOAP Error: " + response.soap_fault.to_s if response.soap_fault?
      error << "HTTP Error: " + response.http_error.to_s if response.http_error?
      Application.instance.logger.debug(self.class) { "Result: error='#{error.inspect}'" }
      return { error: error }
    end

    result = result_parser(response.to_hash)
    result
  end

  def general( owner = 'LIA01', user = 'super:lia01', password = 'super' )
    doc = XmlDocument.new
    root = doc.create_node('general')
    doc.add_namespaces(root, {
      :node_ns   => 'xb',
      'xb'       => 'http://com/exlibris/digitool/repository/api/xmlbeans'})
    doc.root = root
    root << doc.create_text_node('application', 'DIGITOOL-3')
    root << doc.create_text_node('owner', owner)
    root << doc.create_text_node('interface_version', '1.0')
    root << doc.create_text_node('user', user)
    root << doc.create_text_node('password', password)
    doc.document
  end

  protected

  # default parser handles DigiTool response messages
  def result_parser( response )
    result = get_xml_response(response)
    error = nil
    pids = nil
    mids = nil
    de = nil
    doc = XmlDocument.parse(result)
    doc.xpath('//error_description').each { |x| error ||= []; error << x.content unless x.content.nil? }
    doc.xpath('//pid').each { |x| pids ||= []; pids << x.content unless x.content.nil?}
    doc.xpath('//mid').each { |x| mids ||= []; mids << x.content unless x.content.nil?}
    doc.xpath('//xb:digital_entity').each { |x| de ||= []; de << x.to_s }
    { errors: error, pids: pids, mids: mids, digital_entities: de }
  end

  def get_xml_response( response )
    response.first[1][response.first[1][:result].to_sym]
  end

end

