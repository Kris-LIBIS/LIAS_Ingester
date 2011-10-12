# coding: utf-8

require 'net/http'
require 'set'

class Net::HTTPResponse
  #noinspection RubyResolve
  attr_accessor :final_uri
end


module Net

  begin
    require 'net/https'
    HTTPS_SUPPORTED = true
  rescue LoadError
  end

  class HTTP
    def self.fetch(uri, args={}.freeze, &before_fetching)
      uri = URI.parse(uri) unless uri.is_a? URI
      proxy_host    = args[:proxy_host]
      proxy_port    = args[:proxy_port] || 80
      action        = args[:action] || :get
      data          = args[:data]
      max_redirects = args[:max_redirects] || 10

      proxy_class   = Proxy(proxy_host, proxy_port)
      #noinspection RubyArgCount
      request       = proxy_class.new(uri.host, uri.port)

      request.use_ssl = true if HTTPS_SUPPORTED && uri.scheme.eql?('https')

      yield request if block_given?
#debugger
      response = request.send(action, uri.path, data)

      urls_seen = args[:_url_seen] || Set.new

      case response
      when Net::HTTPRedirection
        if urls_seen.size < max_redirects && response['Location']
          urls_seen << uri
          new_uri = URI.parse(response['Location'])
          if urls_seen.member? new_uri
            nil
          else
            new_args = args.dup
            new_args[:_urls_seen] = urls_seen

            response = HTTP.fetch(new_uri, new_args, &before_fetching)
          end
        end
      when Net::HTTPSuccess
        response.final_uri = uri
      else
        response.error!
      end
      return response
    end
  end
end