module AlephSequential

  def to_aseq
    record = ''
    doc_number = xml_get_text(@xml_document.root.xpath('//doc_number'))
    oai_marc   = @xml_document.root.xpath('//oai_marc').first    

    fixfields = oai_marc.xpath('//fixfield')
    varfields = oai_marc.xpath('//varfield')

    fixfields.each do |f|        
      record += "#{format("%09s",doc_number)} #{f['id']}   L #{f.content}\n"
    end
    varfields.each do |v|
      head = "#{format("%09s",doc_number)} #{v['id']}#{v['i1']}#{v['i2']} L "
      subfields = v.xpath('subfield')
      subfields.each do |s|
        head += "$$#{s['label']}#{s.content}"
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