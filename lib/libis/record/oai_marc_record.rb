# coding: utf-8

require 'cgi'

require 'tools/xml_document'

require_relative 'marc_record'

class OaiMarcRecord < MarcRecord

  private

  def get_all_records

    @all_records = Hash.new { |h, k| h[k] = [] }

    @node.xpath('.//fixfield').each { |f|
      tag = f['id']
      tag = '%03d' % tag.to_i if tag.size < 3
      x = f.content
      if x =~ /[\n\r\t\s]*"([^"]*)"[\n\r\t\s]*/
        x = $1
      else
        # Aleph OAI-PMH MARC bug
        x.gsub!('^', ' ')
      end

      @all_records[tag] << FixField.new(tag, CGI::escapeHTML(x))
    }

    @node.xpath('.//varfield').each { |v|

      tag = v['id']
      tag = '%03d' % tag.to_i if tag.size < 3

      subfields = Hash.new { |h, k| h[k] = [] }
      v.xpath('.//subfield').each { |s|
        # XService bug
        content_array = s.content.split('$$')
        content = content_array.shift || ''
        sf = s['label']
        subfields[sf] << CGI::escapeHTML(content)
        content_array.each { |c| subfields[c[0]] << CGI::escapeHTML(c[1..-1]) }
      }

      @all_records[tag] << VarField.new(tag, v['i1'].to_s, v['i2'].to_s, subfields)

    }

    if @all_records['001'].empty?
      doc_number = XmlDocument::get_content @node.xpath('../../doc_number')
      @all_records['001'] << FixField.new('001', doc_number)
    end

    @all_records

  end

end