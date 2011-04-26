require "dm-core"

class Protection
  include DataMapper::Resource

  property    :id,              Serial, :key => true
  property    :usage_type,      String, :required => true
  property    :ptype,           Enum[ :ID, :WATERMARK, :CUSTOM ], :required => true, :default => :NONE
  property    :pinfo,           Yaml, :length => 2000
  property    :negate,          Boolean
  property    :mid,             String, :required => false

  belongs_to  :ingest_run, :required => false
  belongs_to  :ingest_config, :required => false

  def self.from_value( v )
    prot = Protection.new
    prot.mid = nil
    prot.negate = false
    if v.is_a? Integer
      prot.ptype   = :ID
      prot.pinfo   = v.to_s
      prot.mid     = v.to_s
    elsif v =~ /^\s*ID\s*(!?)=\s*(\d+)\s*$/i
      prot.ptype   = :ID
      prot.pinfo   = $2
      prot.mid     = $2
      prot.negate  = true if $1 == "!"
    elsif v =~ /WATERMARK\s*=\s*(.+)$/i
      prot.ptype   = :WATERMARK
      prot.pinfo   = $1
    else
      prot.ptype   = :CUSTOM
      prot.pinfo   = parse_custom(v)
    end
    return prot
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

  def debug_print(indent = 0)
    p ' ' * indent + self.inspect
  end

end

