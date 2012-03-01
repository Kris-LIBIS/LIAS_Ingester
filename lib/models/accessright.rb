# coding: utf-8

require 'dm-core'

require 'ingester_task'

#noinspection RubyResolve
class Accessright
  include DataMapper::Resource
  include IngesterTask

  property    :id,              Serial
  property    :ar_type,         Enum[ :ID, :WATERMARK, :CUSTOM ], required: true
  property    :ar_info,         Yaml, :length => 2000
  property    :negate,          Boolean
  property    :mid,             String, :required => false

  has n,      :ar_model_links

  belongs_to  :ingest_object,   required: false

  # @param v [String] String containing the accessright definition
  def self.from_value( v )
    ar = Accessright.new
    ar.ar_info = nil
    ar.mid = nil
    ar.negate = false
    if v.is_a? Integer
      ar.ar_type   = :ID
      ar.ar_info   = {:id => v}
      ar.mid     = v.to_s
    elsif v =~ /^\s*ID\s*(!?)=\s*(\d+)\s*$/i
      ar.ar_type   = :ID
      ar.ar_info   = {:id => $2}
      ar.mid     = $2
      ar.negate  = true if $1 == "!"
    elsif v =~ /WATERMARK\s*=\s*"(.+)"$/i
      ar.ar_type   = :WATERMARK
      ar.ar_info   = {:text => $1}
    else
      ar.ar_type   = :CUSTOM
      ar.ar_info   = parse_custom(v)
    end
    debug "Accessright created: '#{v}'"
    return ar
  end

  def self.parse_custom(value)
    accessrights = { :conditions => Array.new }
    value.split('||').each do |termlist|
      condition = {:negate => false, :expressions => Array.new }
      if termlist =~ /^\s*copyright\s*=\s*(.+)\s*$/i
        accessrights[:copyright] = $1
        next
      end
      if termlist =~ /^\s*not\s*(.+)\s*/
        condition[:negate] = true
        termlist = $1
      end
      accessrights[:conditions] << condition
      termlist.split('&&').each do |term|
        expression = {:negate => false, :operation => 'eq', :key => '', :val1 => '', :val2 => ''}
        if term =~ /^\s*copyright\s*=\s*(.+)\s*$/i
          accessrights[:copyright] = $1
          next
        end
        if term =~ /^\s*USER\s(!?)=\s*(.+)\s*/i
          expression[:key]    = 'user_id'
          expression[:negate] = ($1 == '!')
          expression[:val1]   = $2
          expression[:operation] = 'within' if expression[:val1] =~ /,/
        elsif term =~ /^\s*GROUP\s(!?)=\s*([\d,]+)\s*/i
          expression[:key]    = 'group'
          expression[:negate] = ($1 == '!')
          expression[:val1]   = $2
          expression[:operation] = 'within' if expression[:val1] =~ /,/
        elsif term =~ /^\s*IP\s(!?)=\s*(\d+\.\d+\.\d+\.\d+)\s*-\s*(\d+\.\d+\.\d+\.\d+)\s*$/i
          expression[:key]    = 'ip_range'
          expression[:negate] = ($1 == '!')
          expression[:val1]   = $2
          expression[:val2]   = $3
          expression[:operation] = 'within'
        end
        condition[:expressions] << expression
      end
    end
    return accessrights
  end

  def is_watermark?
    self.ar_type == :WATERMARK
  end

  def is_id?
    self.ar_type == :ID
  end

  def is_custom?
    self.ar_type == :CUSTOM
  end

  def get_watermark
    return nil unless is_watermark?
    self.ar_info[:text]
  end

  def get_id
    return nil if is_watermark?
    self.mid
  end

  def set_id(id)
    self.mid = id.to_s
  end

  def get_custom
    return nil unless is_custom?
    self.ar_info
  end

  def debug_print(indent = 0)
    p ' ' * indent + self.inspect
  end

end