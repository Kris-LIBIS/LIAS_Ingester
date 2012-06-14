# coding: utf-8

require 'tools/http_fetch'

class GenericSearch
  #noinspection RubyResolve
  attr_accessor :host
  #noinspection RubyResolve
  attr_reader :term, :index, :base
  #noinspection RubyResolve
  attr_reader :num_records, :set_number
  #noinspection RubyResolve
  attr_reader :record_pointer, :session_id
  
  def query(term, index, base, options = {})
    puts "to be implemented"
  end
  
  def each
    puts "to be implemented"    
  end

  def next_record
    puts "to be implemented"
  end

end