require 'rubygems'
require 'nokogiri'
require 'cgi'

class Array
  def add( element, condition = nil )
    if condition
      self << element unless element == condition
    else
      self << element unless element.empty?
    end
    self
  end
  
  def collapse!( separator )
    x = self.join( separator )
    self.clear
    self.add x
  end
  
end

module DublinCore
  
  def to_dc(label)
    aleph_record = self
    
    return nil if aleph_record.nil?
    
    Nokogiri::XML::Builder.new do |xml|
      xml.record('xmlns:dc' => 'http://purl.org/dc/elements/1.1',
                 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                 'xmlns:dcterms' => 'http://purl.org/dc/terms') {
        
        # ######## DC:IDENTIFIER for label
        xml['dc'].identifier label
        
        # ######## DC:IDENTIFIER
        xml['dc'].identifier aleph_record.tag('001').first.datas.strip
        
        aleph_record.tag('035').each do |t|
          xml['dc'].identifier t.subfield['a']
        end
        
        # ######## DC:TITLE
        aleph_record.tag('245').each do |t|
          tTitle = []
          tTitle.add t.subfield['a']
          tTitle.add t.subfield['b'] 
          tTitle.add "[#{t.subfield['h'].gsub(/\[|\]/,'')}]" '[]'
          x = tTitle.join(' ')
          
          xml['dc'].title x unless x.empty?
        end
        
        # ######## DC:CREATOR
        aleph_record.tag('700').each do |t|
          tCreator = []
          tCreator.add t.subfield['a']
          tCreator.add t.subfield['b']
          tCreator.add t.subfield['c']
          tCreator.add t.subfield['d']
          tCreator.add t.subfield['g']
          tCreator.collapse! ','
          
          tCreator.add "(#{t.subfield['4']})", '()'
          tCreator.add aleph_record.tag('710').first.subfield['4'] unless aleph_record.tag('710').empty? || !aleph_record.tag('710').first.subfield['4'].eql?('cph')
          tCreator.collapse! ' '
          
          tCreator.add t.subfield['e']
          x = tCreator.join(', ')
          
          xml['dc'].creator x unless x.empty?
        end
        
        aleph_record.tag('710').each do |t|
          relator = ''
          tCreator = []
          tCreator.add t.subfield['a']
          relator = []
          relator.add t.subfield['g']
          relator.add "(#{t.subfield['4']})" if t.subfield['4'].eql?('cph')
          tCreator.add relator.join(' ')
          tCreator.add t.subfield['e']
          x = tCreator.join(',')
          
          xml['dc'].creator x unless x.empty?
        end
        
        aleph_record.tag('711').each do |t|
          tCreator = []
          tCreator.add t.subfield['a']
          tCreator.add t.subfield['b']
          tCreator.add t.subfield['c']
          tCreator.add t.subfield['d']
          tCreator.add t.subfield['4']
          x = tCreator.join(',')
          
          xml['dc'].creator x unless x.empty?
        end
        
        # ######## DC:SUBJECT
        aleph_record.tag('69002').each do |t|
          x = t.subfield['a']
          xml['dc'].subject x unless x.empty?
        end
        
        # ######## DC:DESCRIPTION
        aleph_record.tag('598').each do |t|
          x = t.subfield['a']
          xml['dc'].description x unless x.empty?
        end
        
        aleph_record.tag('597').each do |t|
          x = t.subfield['a']
          xml['dc'].description x unless x.empty?
        end
        
        aleph_record.tag('500').each do |t|
          x = t.subfield['a']
          xml['dc'].description x unless x.empty?
        end
        
        aleph_record.tag('520').each do |t|
          x = t.subfield['a']
          xml['dc'].description x unless x.empty?
        end
        
        # ######## DC:PROVENANCE
        xml['dcterms'].provenance 'KADOC'
        
        # ######## DC:PUBLISHER
        aleph_record.tag('260').each do |t|
          pub = []
          pub.add t.subfield['b'] 
          pub.add t.subfield['a']
          pub.collapse! ' '
          pub.add t.subfield['c'] unless pub.size == 0
          x = pub.join(', ')
          
          xml['dc'].publisher x unless x.empty?
          
        end
        
        aleph_record.tag('260').each do |t|
          pub = []
          pub.add t.subfield['f']
          pub.add t.subfield['e']
          pub.collapse! ' '  
          pub.add t.subfield['g']
          x = pub.join(', ')
          
          xml['dc'].publisher x unless x.empty?
        end
        
        # ######## DC:DATE
        tagDate = aleph_record.tag('008').first.datas.gsub(/\^/, ' ').gsub(/u/,'X')
        date = []
        date.add tagDate[7..10].strip
        date.add '-' + tagDate[11..14].strip '-'
        date_string = date.join('')
        
        xml['dc'].date date_string unless date_string.empty?
        
        # ######## DC:TYPE
        aleph_record.tag('655 9').each do |t|
          xml['dc'].type t.subfield['a'] unless t.subfield['a'].empty?
        end
        
        aleph_record.tag('088 9').each do |t|
          xml['dc'].type t.subfield['a'] unless t.subfield['a'].empty?
        end
        
        aleph_record.tag('655 4').each do |t|
          xml['dc'].type t.subfield['a'] unless t.subfield['a'].empty?
        end
        
        aleph_record.tag('955  ').each do |t|
          xml['dc'].type t.subfield['a'] unless t.subfield['a'].empty?
        end
        
        aleph_record.tag('69002').each do |t|
          odis_url = 'http://www.odis.be/lnk/'
          odis_match = t.subfield['0'].match(/^\(ODIS-(PS|ORG)\)(\d*$)/)
          
          unless odis_match.nil?
            if odis_match.size == 3
              if odis_match[1].eql?('PS')
                odis_url += "ps_#{odis_match[2]}"
              elsif odis_match[1].eql?('ORG')
                odis_url += "or_#{odis_match[2]}"
              end
            end
            
            x = t.subfield['a']
            odis_url += "##{CGI::escape(x)}" unless x.empty?
            
            xml['dc'].identifier('xsi:type' => 'dcterms:URI').text(odis_url)
          end
        end
        
        fmt_mapping= { 'BK' => 'Books',
          'SE' => 'Continuing Resources',
          'MU' => 'Music',
          'MP' => 'Maps',
          'VM' => 'Visual Materials',
          'AM' => 'Audio Materials',
          'CF' => 'Computer Files',
          'MX' => 'Mixed Materials'               
        }
        
        aleph_record.tag('FMT').each do |t|
          
          if t.members.include?('datas')          
            xml['dc'].type fmt_mapping[t.datas]
          end
        end
        
        # ######## DC:FORMAT
        tag340 = []
        aleph_record.tag('340').each do |t|
          tag340.add t.subfield['a']
        end
        
        tag339 = []
        aleph_record.tag('339').each do |t|
          tag339.add t.subfield['a']
        end
        
        tag319 = []
        aleph_record.tag('319').each do |t|
          tag319.add t.subfield['a']
        end
        
        tag300 = []
        aleph_record.tag('3009').each do |t|
          format = []
          format.add t.subfield['b'].gsub(';','')
          format.add t.subfield['c']
          format.add t.subfield['9']
          
          tag300 << format.join(';')
        end
        
        lines = []
        
        tag300.each do |p|
          line = []
          line << p
          
          if tag300.size == 1
            line << tag340 if (tag340.size > 0)
            line << tag339 if (tag339.size > 0)
            line << tag319 if (tag319.size > 0)
          end
          
          lines << line.compact.join(':')
        end
        lines.compact!
        
        lines.each do |line|
          xml['dc'].format line
        end
        
        # ######## DC:SOURCE
        sources = []
        aleph_record.tag('852').each do |t|
          s = []
          
          if t.subfield['b'].eql?(t.subfield['c'])
            s.add t.subfield['b'] 
          else
            s.add t.subfield['b']
            s.add t.subfield['c']
          end
          
          s.add t.subfield['h']
          s.add t.subfield['l']
          
          sources << s.join(' ')
        end
        
        sources.uniq!
        sources.each do |s|
          xml['dc'].source s
        end
        
        sources = []
        aleph_record.tag('856').each do |t|
          s = []
          archief_url = ''
          
          s.add t.subfield['y']
          
          unless t.subfield['u'].empty?
            archief_url << t.subfield['u']
            archief_url += "##{CGI::escape(t.subfield['y'])}"
          end
          
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text(archief_url)
          
          sources << s.join('')
        end
        
        sources.uniq!
        sources.each do |s|
          xml['dc'].source s
        end
        
        # ######## DC:LANGUAGE
        tagLang = aleph_record.tag('008').first.datas.gsub('^', ' ')
        xml['dc'].language "#{tagLang[35..37]}".strip
        
        tagLang = aleph_record.tag('041').first
        xml['dc'].language tagLang.subfield['a'] unless tagLang.nil?
        
        # ######## DC:RIGHTS
        rights = {'adp' => 'adaptor', 'rpy' => 'verantwoordelijke uitgever', 'dsr' => 'ontwerper', 'pht' => 'fotograaf',
          'cph' => 'copyright', 'ill' => 'illustrator', 'ive' => 'geinterviewde', 'ivr' => 'interviewer',
          'aut' => 'auteur', 'ccp' => 'concept'}
        
        aleph_record.tag('700').each do |t|
          if t.subfield['4'].eql?('cph')
            xml['dc'].source t.subfield['a']
          end
        end
        
        aleph_record.tag('710').each do |t|
          if t.subfield['4'].eql?('cph')
            xml['dc'].source t.subfield['a']
          end
        end
      }
    end.to_xml(:encoding => 'utf-8', :indent => 2)
    
  end
end
