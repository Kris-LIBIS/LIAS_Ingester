# coding: utf-8

class String

  def blank?
    self == ''
  end

  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def escape_for_regexp
    self.gsub(/[\.\+\*\(\)\{\}\|\/\\\^\$"']/) { |s| '\\' + s[0].to_s }
  end

  def escape_for_string
    self.gsub(/['"]/) { |s| '\\' + s[0].to_s }
  end

  def dot_net_clean
    self.gsub /^(\d+|error|float|string);\\?#/, ''
  end

end