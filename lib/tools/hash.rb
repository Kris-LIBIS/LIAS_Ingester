# coding: utf-8

class Hash
#  alias :orig_sqb :[]
#  def [](p)
#    result = orig_sqb(p)
#    return '' if result.nil?
#    return result
#  end
  def key_strings_to_symbols!(opts = {})
    self.replace self.key_strings_to_symbols opts
  end

  NO_DUP_CLASSES = [TrueClass, FalseClass]

  def key_strings_to_symbols(opts = {})
    opts = {resursive: false, upcase: false, downcase: false}.merge opts

    r = Hash.new
    self.each_pair do |k,v|

      k = k.to_s if k.kind_of? Symbol
      if k.kind_of? String
        k = k.downcase if opts[:downcase]
        k = k.upcase if opts[:upcase]
        k = k.to_sym
      end

      if opts[:recursive]
        case v
          when Hash
            v = v.key_strings_to_symbols opts
          when Array
            v = v.collect { |a| (a.kind_of? Hash) ? a.key_strings_to_symbols(opts) :  Marshal.load(Marshal.dump(a)) }
          else
            v = Marshal.load(Marshal.dump(v))
        end
      end

      r[k] = v

    end

    r
  end

  def key_symbols_to_strings!(opts = {})
    self.replace self.key_symbols_to_strings opts
  end

  def key_symbols_to_strings(opts = {})
    opts = {resursive: false, upcase: false, downcase: false}.merge opts

    r = Hash.new
    self.each_pair do |k,v|

      k = k.to_sym if k.kind_of? String
      if k.kind_of? Symbol
        k = k.to_s
        k = k.downcase if opts[:downcase]
        k = k.upcase if opts[:upcase]
      end

      if opts[:recursive]
        case v
          when Hash
            v = v.key_symbols_to_strings(opts)
          when Array
            v = v.collect { |a| (a.kind_of? Hash) ? a.key_symbols_to_strings(opts) : Marshal.load(Marshal.dump(a)) }
          else
            v = Marshal.load(Marshal.dump(v))
        end
      end

      r[k] = v

    end

    r
  end

  def recursive_merge(other_hash)
    self.merge(other_hash) do |_, old_val, new_val|
      if old_val.is_a? Hash
        old_val.recursive_merge new_val
      else
        new_val
      end
    end
  end

  def recursive_merge!(other_hash)
    self.merge!(other_hash) do |_, old_val, new_val|
      if old_val.is_a? Hash
        old_val.recursive_merge new_val
      else
        new_val
      end
    end
  end

end
