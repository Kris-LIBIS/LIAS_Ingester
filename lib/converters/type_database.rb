require 'singleton'

require 'application'

class TypeDatabase
  include Singleton

  attr_reader :types

  def self.type2media(t)
    @type2media_map[t]
  end

  def self.type2mime(t)
    @type2mime_map[t]
  end

  def self.type2ext(t)
    @type2ext_map[t].first
  end

  def self.media2type(media)
    @type2media_map.select do |k,v|
      v == media
    end.keys
  end

  def self.mime2type(mime)
    @type2mime_map.invert[mime]
  end

  def self.ext2type(ext)
    @type2ext_map.each do |k,v|
      return k if v.include? ext
    end
    nil
  end

  def self.load_config(file)
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
        @type2mime_map[type] = t[:MIME]
        @type2ext_map[type]  = t[:EXTENSIONS].split(',')
      end
    end
  end

  private

  def initialize
    load_config(Application.dir + '/config/types.yaml')
  end

end
