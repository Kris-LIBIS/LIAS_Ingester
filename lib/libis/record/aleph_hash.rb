module AlephHash
  def to_h
    record = {}
    doc_number = xml_get_text(@xml_document.root.find('//doc_number'))
    oai_marc   = @xml_document.root.find('//oai_marc').first   
    
    fixfields = oai_marc.find('//fixfield')
    varfields = oai_marc.find('//varfield') 
    
    fixfields.each do |f|        
      tag = f.attributes['id']      
      datas = f.content

      record_datas = []
      if record.include?(tag)
        record_datas = record[tag]
      end
      
      record_datas << {:ind1 => '', :ind2 => '', :subfields => {}, :datas => datas}
      record[tag] = record_datas
    end           
    
    varfields.each do |v|
      subfields = {}
      
      tag = v.attributes['id']
      ind1 = v.attributes['i1']
      ind2 = v.attributes['i2']
      
      subfields_data = v.find('subfield')
      subfields_data.each do |s|
        subfields.store(s.attributes['label'], s.content)
      end
      record_datas = []
      if record.include?(tag)
        record_datas = record[tag]
      end
      
      record_datas << {:ind1 => ind1.to_s, :ind2 => ind2.to_s, :subfields => subfields, :datas => ""}
      record[tag] = record_datas
    end
    
    record
  end  
end