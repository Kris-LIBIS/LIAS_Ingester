module AlephSequential
  def to_aseq
    record = ''
    doc_number = xml_get_text(@xml_document.root.find('//doc_number'))
    oai_marc   = @xml_document.root.find('//oai_marc').first    

    fixfields = oai_marc.find('//fixfield')
    varfields = oai_marc.find('//varfield')

    fixfields.each do |f|        
      record += "#{format("%09s",doc_number)} #{f.attributes['id']}   L #{f.content}\n"
    end
    varfields.each do |v|
      head = "#{format("%09s",doc_number)} #{v.attributes['id']}#{v.attributes['i1']}#{v.attributes['i2']} L "
      subfields = v.find('subfield')
      subfields.each do |s|
        head += "$$#{s.attributes['label']}#{s.content}"
      end
      record += head + "\n"
    end    
  
    record
  end
  
private
  def xml_get_text(xpath)
    text = ''
    if xpath.size == 1
      text = xpath.first.content        
    end

    text
  end  
end  