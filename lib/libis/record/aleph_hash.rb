module AlephHash
  def to_h
    record = {}
    doc_number = xml_get_text(@xml_document.root.xpath('//doc_number'))
    oai_marc   = @xml_document.root.xpath('//oai_marc').first
    
    fixfields = oai_marc.xpath('//fixfield')
    varfields = oai_marc.xpath('//varfield')
    
    fixfields.each do |f|
      tag = f['id']
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
      
      tag = v['id']
      ind1 = v['i1']
      ind2 = v['i2']
      
      subfields_data = v.xpath('subfield')
      subfields_data.each do |s|
        subfields.store(s['label'], s.content)
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