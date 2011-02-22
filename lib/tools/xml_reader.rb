require 'nokogiri'

module XmlReader
  
  def self.parse_file( file_name )
  	doc = nil
    File.open( file_name ) do |fp|
      doc = Nokogiri::XML::Document.parse( fp )
    end
    return doc
  end
  
  def self.parse_string( string )
    return Nokogiri::XML::Document.parse( string )
  end

end

