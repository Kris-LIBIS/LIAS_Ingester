# coding: utf-8

class DcElement

  attr_accessor :parts
  attr_accessor :prefix
  attr_accessor :join
  attr_accessor :postfix

  def initialize(*parts)
    @parts = []
    self[*parts]
  end

  def add_options(options = {})
    if options[:fix]
      if options[:fix].size == 2
        @prefix, @postfix = options[:fix].split('')
      else
        @prefix, @postfix = options[:fix].split('|')
      end
    end
    @join = options[:join] if options[:join]
    @prefix = DcElement::from(options[:prefix]) if options[:prefix]
    @postfix = DcElement::from(options[:postfix]) if options[:postfix]
    self
  end

  def add_default_options(options = {})
    options.delete(:prefix) if @prefix
    options.delete(:postfix) if @postfix
    options.delete(:fix) if @prefix or @postfix
    options.delete(:join) if @join
    add_options options
  end

  def [](*parts)
    options = parts.last.is_a?(Hash) ? parts.pop : {}
    parts.each {|x| add x}
    x = options.delete(:parts)
    add x if x
    add_options options
  end

  def self.from(*h)
    DcElement.new(*h)
  end

  def to_s
    @parts.delete_if() { |x|
      x.nil? or
          (x.is_a? String and x.empty?) or
          (x.is_a? DcElement and x.to_s.empty? )
    }
    result = @parts.join(@join)
    unless result.empty?
      result = (@prefix || '').to_s + result + (@postfix || '').to_s
    end
    result
  end

  def add(part)
    case part
      when Hash
        @parts << DcElement::from(part)
      when Array
        part.each { |x| add x }
      else
        @parts << part
    end
  end

end