# coding: utf-8

class String

  def blank?
    self == ''
  end

  def sort_form
    result = []
    matcher = /^(\D*)(\d*)(.*)$/
    self.split('.').each { |s|
      while !s.empty? and (x = matcher.match s)
        a = x[1].to_s.strip
        b = a.gsub(/[ _]/, '')
        result << [b.downcase, b, a]
        result << x[2].to_i
        s = x[3]
      end
    }
    result
  end

  def underscore
    self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr("-", "_").
        downcase
  end

  def quote
    '\"' + self.gsub(/"/) { |s| '\\' + s[0] } + '\"'
  end

  def escape_for_regexp
    self.gsub(/[\.\+\*\(\)\{\}\|\/\\\^\$"']/) { |s| '\\' + s[0].to_s }
  end

  def escape_for_string
    self.gsub(/"/) { |s| '\\' + s[0].to_s }
  end

  def escape_for_cmd
    self.gsub(/"/) { |s| '\\\\\\' + s[0].to_s }
  end

  def escape_for_sql
    self.gsub(/'/) { |s| ($` == '' || $' == '' ? '' : '\'') + s[0].to_s }
  end

  def dot_net_clean
    self.gsub /^(\d+|error|float|string);\\?#/, ''
  end

  def remove_whitespace
    self.gsub(/\s/, '_')
  end

  def encode_visual(regex = nil)
    regex ||= /\W/
    self.gsub(regex) { |c| '_x' + '%04x' % c.unpack('U')[0] + '_'}
  end

  def decode_visual
    self.gsub(/_x([0-9a-f]{4})_/i) { [$1.to_i(16)].pack('U') }
  end

end