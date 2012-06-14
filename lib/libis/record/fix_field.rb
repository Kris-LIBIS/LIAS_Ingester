# coding: utf-8

class FixField

  attr_reader :tag
  attr_reader :datas

  def initialize(tag, datas)
    @tag = tag
    @datas = datas || ''
  end

  def dump
    "#@tag:'#@datas'\n"
  end

end