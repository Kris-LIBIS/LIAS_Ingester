class Hash
#  alias :orig_sqb :[]
#  def [](p)
#    result = orig_sqb(p)
#    return '' if result.nil?
#    return result
#  end
  def key_strings_to_symbols!(opts = {})
    opts = {:resursive => false, :upcase => false, :downcase => false}.merge opts
    r = Hash.new
    self.each_pair do |k,v|
      if (k.kind_of? String)
        v.key_strings_to_symbols!(opts) if opts[:recursive] and v.kind_of? Hash and v.respond_to? :key_strings_to_symbols!
        if opts[:recursive] and v.kind_of? Array
          v.collect {|a| (a.kind_of? Hash and a.respond_to? :key_strings_to_symbols!) ? a.key_strings_to_symbols!(opts) : a }
        end
        k = k.downcase if opts[:downcase]
        k = k.upcase if opts[:upcase]
        r[k.to_sym] = v

      else
        v.key_strings_to_symbols!(opts) if opts[:recursive] and v.kind_of? Hash and v.respond_to? :key_strings_to_symbols!
        if opts[:recursive] and v.kind_of? Array
          v.collect  {|a| (a.kind_of? Hash and a.respond_to? :key_strings_to_symbols!) ? a.key_strings_to_symbols!(opts) : a }
        end
        r[k] = v
      end
    end
    self.replace(r)
  end

  def key_symbols_to_strings!(opts = {})
    opts = {:resursive => false, :upcase => false, :downcase => false}.merge opts
    r = Hash.new
    self.each_pair do |k,v|
      if (k.kind_of? Symbol)
        v.key_symbols_to_strings!(opts) if opts[:recursive] and v.kind_of? Hash and v.respond_to? :key_symbols_to_strings!
        if opts[:recursive] and v.kind_of? Array
          v.collect {|a| (a.kind_of? Hash and a.respond_to? :key_symbols_to_strings!) ? a.key_symbols_to_strings!(opts) : a }
        end
        k = k.to_s
        k = k.downcase if opts[:downcase]
        k = k.upcase if opts[:upcase]
        r[k] = v
      else
        v.key_symbols_to_strings!(opts) if opts[:recursive] and v.kind_of? Hash and v.respond_to? :key_symbols_to_strings!
        if opts[:recursive] and v.kind_of? Array
          v.collect  {|a| (a.kind_of? Hash and a.respond_to? :key_symbols_to_strings!) ? a.key_symbols_to_strings!(opts) : a }
        end
        r[k] = v
      end
    end
    self.replace(r)
  end

end
