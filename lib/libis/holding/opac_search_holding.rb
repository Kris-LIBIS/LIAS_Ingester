require 'libis/holding/generic_search_holding'

class OpacSearchHolding < GenericSearchHolding
  def retrieve
    response = Net::HTTP.fetch(@host, :data => "op=item-data&base=#{@base}&doc-number=#{@doc_number}", :action => :post)
    
    if response.is_a?(Net::HTTPOK)  
      puts @doc_number
      puts response.body
    else
      puts
      puts "----------> Error searching for #{@term} --> '#{error}'"            
      puts 
      if error =~ /license/
        redo_search = true
        sleep 5
      end      
    end
  end
end