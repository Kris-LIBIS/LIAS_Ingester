# coding: utf-8

class VirusScanner

  #noinspection RubyResolve
  attr_reader :more_info

  def check(file_path)
    @file_path = file_path
    true
  end
end
