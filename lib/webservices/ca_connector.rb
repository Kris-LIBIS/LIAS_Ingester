# coding: utf-8

require_relative 'soap_client'

#noinspection RubyStringKeysInHashInspection
class CaConnector
  include SoapClient

  attr_accessor :type_cast

  def initialize(service, host = nil)
    @type_cast = true
    @host = host || 'http://crkc.be.halotest.cc.kuleuven.be/ca_crkc'
    @service = service
    setup @service
  end

  def init
    @wsdl_url = "#@host/service.php/#{@service.downcase}/#@service/soapWSDL"

    Nori.parser = :nokogiri

    Nori.configure do |config|
      config.convert_tags_to do |tag|
        %w(Envelope Body).include?(tag) ? tag.snakecase.to_sym : tag.to_sym
      end
    end

    Gyoku.configure do |config|
      config.convert_symbols_to :none
    end

    Nori.strip_namespaces = true
  end

  def authenticate(name = nil, password = nil)
    name ||= 'administrator'
    password ||= 'administrator'
    result = request :auth, username: name, password: password
    result.to_i == 1
  end

  def deauthenticate
    request :deauthenticate
  end

  protected

  def result_parser(result)
    type_caster(result.first[1][result.first[1][:result].snakecase.to_sym])
  end

  def type_caster(result)
    return result unless @type_cast
    return result unless result.is_a? Hash

    r = result

    case r[:"@xsi:type"]
      when "enc:Array"
        elements = result[:item]
        if elements.is_a? Array
          r = Array.new
          elements.each { |i| r << type_caster(i) }
        else
          r = type_caster(result[:item])
        end

      when "ns2:Map"
        r = {}
        elements = result[:item]
        unless elements.is_a? Array
          elements = Array.new
          elements << result[:item]
        end

        elements.each { |i|
          key = i[:key]
          value = i[:value]
          value = type_caster(value)
          r[key] = value
        }
      else
        #do nothing
    end
    r
  end

  NS_ATTR_ENC = {'xmlns:enc' => 'http://schemas.xmlsoap.org/soap/encoding/'}
  NS_ATTR_NS2 = {'xmlns:ns2' => 'http://xml.apache.org/xml-soap'}

  def soap_encode(data)
    result = data
    attributes = nil
    case data
      when Array
        i = data.size
        t = type_string data[0]
        attributes = {'xsi:type' => 'enc:Array'}
        if t
          attributes['enc:arrayType'] = "#{t}[#{i}]"
        else
          attributes['enc:arraySize'] = i
        end
        attributes.merge! NS_ATTR_ENC
        if t =~ /^ns2:/
          attributes.merge! NS_ATTR_NS2
        end
        result = Array.new
        data.each { |x|
          r, a = soap_encode x
          i = { item: r}
          i[:attributes!] = { item: a } if a
          result << i
        }
      when Hash
        attributes = {'xsi:type' => 'ns2:Map'}.merge NS_ATTR_NS2
        result = {item: Array.new}
        data.each { |k, v|
          rk, ak = soap_encode k.to_s
          rv, av = soap_encode v
          i = { key: rk, value: rv}
          i[:attributes!] = {}
          i[:attributes!][:key] = ak if ak
          i[:attributes!][:value] = av if av
          result[:item] << i
        }
      else
        t = type_string data
        if t
          attributes = { 'xsi:type' => t }
          attributes.merge! NS_ATTR_ENC if t =~ /^enc:/
          attributes.merge! NS_ATTR_NS2 if t =~ /^ns2:/
        end
    end
    return result, attributes
  end

  def type_string(data)
    return nil if data.nil?
    case data
      when Array
        'enc:Array'
      when Hash
        'ns2:Map'
      when String
        'xsd:string'
      when Integer
        'xsd:int'
      else
        'xsd:string'
    end
  end

end