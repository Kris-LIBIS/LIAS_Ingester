# coding: utf-8

require_relative 'search/opac_search'
require_relative 'search/primo_search'
require_relative 'search/sharepoint_search'

class SearchFactory
  def initialize(format)    
    @search_class = self.class.const_get("#{format}Search")
  rescue Exception => e
    puts e.message
    exit -1
  end
  
  def new_search
    @search_class.new
  end
end