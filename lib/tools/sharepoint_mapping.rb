# coding: utf-8

require 'awesome_print'
require 'csv'
require 'tools/hash'

class SharepointMapping < Hash

  def initialize( mapping_file )

    CSV.foreach(mapping_file) do |row|
      next unless row[1]
      next unless row[1].match(/^ows_/)

      name = row[0] ? row[0].strip : nil
      label = row[1].strip.to_sym
      db_column = row[2] ? row[2].strip : nil
      dc_tag = row[3] ? row[3].strip : ''
      scope_tag = row[4] ? row[4].strip : nil
      scope_id = row[5] and row[5] != '?' ? Integer(row[5].strip) : nil

      mapping = {}
      mapping[:fancy_name] = name if name
      mapping[:db_column] = db_column if db_column
      mapping[:scope_tag] = scope_tag if scope_tag
      mapping[:scope_id] = scope_id if scope_id

      if dc_tag.match(/^\s*"(.*)"\s*(<.*)$/)
        mapping[:dc_prefix] = $1
        dc_tag = $2
      end

      if dc_tag.match(/^\s*<dc:[^.]+\.([^.>]+)>(.*)$/)
        mapping[:dc_tag] = "dcterms:#{$1}"
        dc_tag = $2

      elsif dc_tag.match(/^\s*<dc:([^.>]+)>(.*)$/)
        mapping[:dc_tag] = "dc:#{$1}"
        dc_tag = $2
      end

      if dc_tag.match(/^\s*"(.*)"\s*$/)
        mapping[:dc_postfix] = $1
      end

      if ref = SharepointRecord::REF_MAPPER.invert[label]
        mapping[:ref] = ref
      end

      self[label] = mapping.empty? ? nil : mapping

    end

    super nil

  end

  def dc_tag( label )
    mapping = self[label]
    mapping = mapping[:dc_tag] if mapping
    mapping
  end

  def dc_prefix( label )
    mapping = self[label]
    mapping = mapping[:dc_prefix] if mapping
    mapping
  end

  def dc_postfix( label )
    mapping = self[label]
    mapping = mapping[:dc_postfix] if mapping
    mapping
  end

  def name( label )
    mapping = self[label]
    mapping = mapping[:fancy_name] if mapping
    mapping
  end

end