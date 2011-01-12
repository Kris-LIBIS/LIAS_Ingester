require 'lib/tools/http_fetch'

class GenericSearchHolding
    attr_reader :doc_number, :host, :base
  
    def initialize(doc_number, host, base)
      @doc_number = doc_number
      @host = host
      @base = base
      self.retrieve
    end
    
    def each
      puts "to be implemented"
    end
    
    def retrieve
      puts "to be implemented"
    end
end