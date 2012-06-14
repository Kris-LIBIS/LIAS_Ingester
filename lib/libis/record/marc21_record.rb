# coding: utf-8

require 'cgi'

require_relative 'marc_record'

class Marc21Record < MarcRecord

  private

  def get_all_records

    @all_records = Hash.new { |h,k| h[k] = [] }

    @node.xpath('.//leader').each { |f|
      @all_records['LDR'] << FixField.new('LDR',f.content)
    }

    @node.xpath('.//controlfield').each { |f|
      tag = f['tag']
      tag = '%03d' % tag.to_i if tag.size < 3
      @all_records[tag] << FixField.new(tag,CGI::escapeHTML(f.content))
    }

    @node.xpath('.//datafield').each { |v|

      tag = v['tag']
      tag = '%03d' % tag.to_i if tag.size < 3

      subfields = Hash.new { |h, k| h[k] = [] }
      v.xpath('.//subfield').each { |s| subfields[s['code']] << CGI::escapeHTML(s.content) }

      @all_records[tag] << VarField.new(tag, v['ind1'].to_s, v['ind2'].to_s, subfields)

    }

     @all_records

  end

end
