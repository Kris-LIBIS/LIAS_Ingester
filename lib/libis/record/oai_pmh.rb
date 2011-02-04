require 'rubygems'
require 'nokogiri'

module OaiPmh
  def to_oai_pmh
    aleph_record = self

    controlfields = []
    datafields = []
    
    doc_number = xml_get_text(@xml_document.root.xpath('//doc_number'))
    oai_marc   = @xml_document.root.xpath('//oai_marc').first    

    fixfields = oai_marc.xpath('//fixfield')
    varfields = oai_marc.xpath('//varfield')

    fixfields.each do |f|
      controlfields << f['id']
    end
    controlfields.uniq!

    varfields.each do |v|
      datafields << v['id']
    end
    datafields.uniq!

    xml = Nokogiri::Builder::XmlMarkup.new {
      xml.tag!("OAI-PMH",
               "xmlns" => 'http://www.openarchives.org/OAI/2.0/',
               "xmlns:xsi" => 'http://www.w3.org/2001/XMLSchema-instance',
               "xsi:schemaLocation" => 'http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd') {
        xml.ListRecords {
          xml.record {
            xml.header {
              xml.identifier("aleph-publish:#{aleph_record.tag('001').first.datas.strip}")
            }
            xml.metadata {
              xml.record( "xmlns" => "http://www.loc.gov/MARC21/slim",
                         "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
                         "xsi:schemaLocation" => "http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd") {
                xml.leader(aleph_record.tag('LDR').first.datas.gsub('^', ' '))
                
                controlfields.each do |k|
                  xml.controlfield(aleph_record.tag(k).first.datas.gsub('^', ' '), 'tag' => "#{k}")
                end
                
                datafields.each do |k|
                  if k.eql?('FMT')
                    xml.datafield(aleph_record.tag(k).first.datas, 'tag' => "#{k}", 'ind1' => aleph_record.tag(k).first.ind1, 'ind2' => aleph_record.tag(k).first.ind2)
                  else
                    aleph_record.tag(k).each do |r|
                      xml.datafield('tag' => "#{k}", 'ind1' => r.ind1, 'ind2' => r.ind2) {
                        subfields = r.subfield || {}
                        subfields.each do |sk,sv|
                          xml.subfield(sv, 'code'=> sk)
                        end
                      }
                    end
                  end
                end
                xml.datafield('KUL', 'tag' => 'OWN', 'ind1' => '', 'ind2' => '')
                xml.datafield('tag' => 'AVA', 'ind1' => '', 'ind2' => '') {
                  xml.subfield('LBS50', 'code' => 'a')
                  xml.subfield('BIBC', 'code' => 'b')
                  xml.subfield('available', 'code' => 'e')
                }
              }
            }
          }
        }
      }
    }.to_xml(:encoding => 'utf-8', :indent => 2)
  end
  
end
