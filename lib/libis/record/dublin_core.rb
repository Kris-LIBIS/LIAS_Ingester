require 'rubygems'
require 'nokogiri'
require 'cgi'

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
          tTitle << t.subfield['a']
          tTitle << t.subfield['b']
          tTitle << "[#{t.subfield['h'].gsub(/\[|\]/,'')}]" if t.subfield['h']
          
          xml['dc'].title tTitle.join(' ')
        end
        
        # ######## DC:CREATOR
        aleph_record.tag('700').each do |t|
          tCreator = []
          tCreator << t.subfield['a']
          tCreator << t.subfield['b']
          tCreator << t.subfield['c']
          tCreator << t.subfield['d']
          tCreator << t.subfield['g']
          
          tCreator.compact!
          tCreator.delete_if {|i| i.blank? }
          
          sCreator = tCreator.compact.join(',')
          sCreator += " (#{t.subfield['4']})" unless t.subfield['4'].blank?
          sCreator += " #{aleph_record.tag('710').first.subfield['4']}" if !aleph_record.tag('710').empty? && aleph_record.tag('710').first.subfield['4'].eql?('cph')
          sCreator += ", #{t.subfield['e']}" unless t.subfield['e'].blank?
          
          unless sCreator.blank?
            xml['dc'].creator do |creator|
              creator << sCreator
            end
          end
        end
        
        aleph_record.tag('710').each do |t|
          relator = ''
          tCreator = []
          tCreator << t.subfield['a']
          relator += " (#{t.subfield['4']})" if t.subfield['4'].eql?('cph')
          tCreator << t.subfield['g'] + relator
          tCreator << t.subfield['e']
          
          tCreator.delete_if {|i| i.blank?}
          
          unless tCreator.compact.join(',').blank?
            xml['dc'].creator tCreator.compact.join(',')
          end
        end
        
        aleph_record.tag('711').each do |t|
          tCreator = []
          tCreator << t.subfield['a']
          tCreator << t.subfield['b']
          tCreator << t.subfield['c']
          tCreator << t.subfield['d']
          tCreator << t.subfield['4']
          
          tCreator.delete_if {|i| i.blank? }
          
          unless tCreator.compact.join(',').blank?
            xml['dc'].creator tCreator.compact.join(',')
          end
        end
        
        # ######## DC:SUBJECT
        aleph_record.tag('69002').each do |t|
          xml['dc'].subject t.subfield['a']
        end
        
        # ######## DC:DESCRIPTION
        aleph_record.tag('598').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].description t.subfield['a']
          end
        end
        
        aleph_record.tag('597').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].description t.subfield['a']
          end
        end
        
        aleph_record.tag('500').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].description t.subfield['a']
          end
        end
        
        aleph_record.tag('520').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].description t.subfield['a']
          end
        end
        
        # ######## DC:PROVENANCE
        xml['dcterms'].provenance 'KADOC'
        
        # ######## DC:PUBLISHER
        aleph_record.tag('260').each do |t|
          pub = []
          pub << t.subfield['b']
          pub << t.subfield['a']
          pub << ','  if !t.subfield['c'].blank? && (!t.subfield['b'].blank? || !t.subfield['a'].blank?)
          pub << t.subfield['c']
          
          pub.delete_if {|i| i.blank?}
          
          unless pub.compact.join(' ').blank?
            xml['dc'].publisher pub.compact.join(' ')
          end
        end
        
        aleph_record.tag('260').each do |t|
          pub = []
          place_of_manufacture = ''
          pub << t.subfield['f']
          place_of_manufacture = t.subfield['e']
          place_of_manufacture += ', '  if !t.subfield['g'].blank? && (!t.subfield['f'].blank? || !t.subfield['e'].blank?)
          pub << place_of_manufacture
          pub << t.subfield['g']
          
          pub.compact!
          pub.delete_if {|i| i.blank?}
          
          unless pub.compact.join(' ').blank?
            xml['dc'].publisher pub.compact.join(' ')
          end
        end
        
        # ######## DC:DATE
        tagDate = aleph_record.tag('008').first.datas.gsub(/\^/, ' ').gsub(/u/,'X')
        tagDateFrom = tagDate[7..10]
        tagDateTo   = tagDate[11..14]
        
        date_string = "#{tagDateFrom}".strip
        date_string += "-#{tagDateTo}".strip if tagDateTo.strip.size > 0
        
        xml['dc'].date date_string.strip
        
        # ######## DC:TYPE
        aleph_record.tag('655 9').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].type t.subfield['a']
          end
        end
        
        aleph_record.tag('088 9').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].type t.subfield['a']
          end
        end
        
        aleph_record.tag('655 4').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].type t.subfield['a']
          end
        end
        
        aleph_record.tag('955  ').each do |t|
          unless t.subfield['a'].blank?
            xml['dc'].type t.subfield['a']
          end
        end
        
        #      tagType = aleph_record.tag('69002')
        #      tagType.each do |t|
        #        unless t.subfield['a'].blank? || !t.subfield['0'].eql?('ODIS-GEN')
        #          xml['dc'].type do |type|
        #            type << t.subfield['a']
        #          end
        #        end
        #      end
        
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
            
            unless t.subfield['a'].blank?
              odis_url += "##{CGI::escape(t.subfield['a'])}"      
            end
            
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
          unless t.subfield['a'].blank?
            #      xml['dc'].format do |format|
            tag340 << t.subfield['a']
            #      end
          end
        end
        
        tag340.delete_if {|i| i.blank?}
        
        tag339 = []
        aleph_record.tag('339').each do |t|
          tag339 << t.subfield['a']
        end
        
        tag339.delete_if {|i| i.blank?}
        
        tag319 = []
        aleph_record.tag('319').each do |t|
          unless t.subfield['a'].blank?
            #   xml['dc'].format do |format|
            tag319 << t.subfield['a']
            #    end
          end
        end
        
        tag319.delete_if {|i| i.blank?}
        
        tag300 = []
        aleph_record.tag('3009').each do |t|
          format = []
          format << t.subfield['b'].gsub(';','')
          format << t.subfield['c']
          format << t.subfield['9']
          
          format.delete_if {|i| i.blank?}
          
          tag300 << format.compact.join(';')
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
        
        #
        #      highest = tag339.size
        #      highest = tag300.size if highest < tag300.size
        #
        #      highest.times do |i|
        #        line = []
        #        line << tag339[i] if i < tag339.size
        #        line << tag300[i] if i < tag300.size
        #
        #        line.delete_if {|i| i.blank?}
        #        line.compact!
        #
        #        unless line.compact.join(':').blank?
        #          xml['dc'].format do |format|
        #            format << line.compact.join(':')
        #          end
        #        end
        #      end
        
        # ######## DC:SOURCE
        sources = []
        aleph_record.tag('852').each do |t|
          s = []
          
          if t.subfield['b'].eql?(t.subfield['c'])
            s << t.subfield['b']
          else
            s << t.subfield['b']
            s << t.subfield['c']
          end
          
          s << t.subfield['h']
          s << t.subfield['l']
          
          s.delete_if {|i| i.blank?}
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
          
          s << t.subfield['y']
          
          unless t.subfield['u'].blank?
            archief_url << t.subfield['u']
            archief_url += "##{CGI::escape(t.subfield['y'])}"
          end
          
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text(archief_url)
          
          s.delete_if {|i| i.blank?}
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
        unless tagLang.nil?
          xml['dc'].language tagLang.subfield['a']
        end
        
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
