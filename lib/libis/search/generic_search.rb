require_relative '../../tools/http_fetch'

class GenericSearch
  attr_accessor :host
  attr_reader :term, :index, :base
  attr_reader :num_records, :set_number
  attr_reader :record_pointer, :session_id  
  
  def query(term, index, base, options = {})
    puts "to be implemented"
  end
  
  def each
    puts "to be implemented"    
  end
end