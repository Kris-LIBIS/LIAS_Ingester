require 'libis/search/opac_search'
require 'libis/search/primo_search'

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