# coding: utf-8

require 'singleton'

require 'application'

class TypeDatabase
  include Singleton

  def self.type2media(t)
    self.instance.type2media(t)
  end

  def self.type2mime(t)
    self.instance.type2mime(t)
  end

  def self.type2ext(t)
    self.instance.type2ext(t)
  end

  def self.media2type(media)
    self.instance.media2type(media)
  end

  def self.mime2type(mime)
    self.instance.mime2type(mime)
  end

  def self.mime2media(mime)
    self.instance.mime2media(mime)
  end

  def self.ext2type(ext)
    self.instance.ext2type(ext)
  end

  def type2media(t)
    @type2media_map[t]
  end

  def type2mime(t)
    @type2mime_map[t].first
  end

  def type2ext(t)
    @type2ext_map[t].first
  end

  def media2type(media)
    @type2media_map.select do |_,v|
      v == media
    end.keys
  end

  def mime2type(mime)
    @type2mime_map.each do |t,m|
      return t if m.include? mime
    end
    nil
  end

  def mime2media(mime)
    type2media(mime2type(mime))
  end

  def ext2type(ext)
    @type2ext_map.each do |k,v|
      return k if v.include? ext
    end
    nil
  end

  def known_mime?(mime)
    @type2mime_map.each do |t,m|
      return true if m.include? mime
    end
    false
  end

  private

  def initialize
    load_config(Application.dir + '/config/types.yaml')
  end

  def load_config(file)
    config = YAML.load_file file
    @type2media_map = {}
    @type2mime_map = {}
    @type2ext_map = {}
    @type2options_map = {}
    @types = Set.new
    config[:TYPES].each do |m|
      media = m[:MEDIA]
      m[:TYPE_INFO].each do |t|
        type = t[:TYPE]
        @types.add type
        @type2media_map[type] = media
        @type2mime_map[type] = t[:MIME].split(',')
        @type2ext_map[type]  = t[:EXTENSIONS].split(',')
      end
    end
  end

end
