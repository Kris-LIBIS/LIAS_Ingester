# coding: utf-8

require 'awesome_print'
require 'csv'
require 'yaml'

require 'tools/hash'

class SharepointMapping < Hash

  def initialize( mapping_file )


    CSV.foreach(mapping_file, headers: true, skip_blanks: true) do |row|
      next unless row[1]
      # next unless (row[2] || row[3])

      # compensation for bug in library that reads the Excel data
      0.upto(5) { |i| row[i] = row[i].gsub(/_x005F(_x[0-9a-fA-F]{4}_)/, '\1') if row[i] }

      name = row[0] ? row[0].strip : nil
      label = row[1].strip.to_sym
      dc_tag = row[2] ? row[2].strip : ''
      db_column = row[3] ? row[3].strip : nil
      db_datatype = row[4] ? row[4].strip.upcase.to_sym : nil
      db_valuemask = row[5] ? row[5] : nil
#      scope_tag = row[6] ? row[6].strip : nil
#      scope_id = (row[7] and row[7] =~ /[0-9]+/ ? Integer(row[7].strip) : nil)


      mapping = {}
      mapping[:fancy_name] = name if name
      mapping[:db_column] = db_column if db_column
      mapping[:db_datatype] = :STRING
      mapping[:db_datatype] = db_datatype if db_datatype
      mapping[:db_valuemask] = (mapping[:db_datatype] == :STRING ? "'@@'" : "@@")
      mapping[:db_valuemask] = db_valuemask if db_valuemask
#      mapping[:scope_tag] = scope_tag if scope_tag
#      mapping[:scope_id] = scope_id if scope_id

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

      self[label] = mapping.empty? ? nil : mapping

    end

    File.open('mapping.yml','wt') { |fp|
      fp.puts self.to_yaml
    }
    super nil

  end

  def name( label )
    mapping = self[label]
    mapping = mapping[:fancy_name] if mapping
    mapping || label
  end

  def fancy_label( label )
    mapping = self[label]
    mapping = mapping[:fancy_name] if mapping
    "#{label}#{mapping ? '(' + mapping + ')' : ''}"
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

  def db_column( label )
    mapping = self[label]
    mapping = mapping[:db_column] if mapping
    mapping
  end

  def db_value( label, value )
    mapping = self[label]
    return nil unless mapping
    mask = mapping[:db_valuemask]
    mask.gsub("@@", value.to_s)
  end

end