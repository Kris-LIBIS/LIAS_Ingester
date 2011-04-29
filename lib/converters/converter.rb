class Converter

  @@converters = []
  
  attr_reader :media_type
  
  def self.inherited( klass )
    @@converters << klass
  end
  
  def self.get_converters
    @@converters
  end
  
  def type2mime(t)
    @type2mime_map[t]
  end

  def type2ext(t)
    @type2ext_map[t].first
  end

  def mime2type(mime)
    @type2mime_map.revert[mime]
  end

  def ext2type(ext)
    @type2ext_map.each do |k,v|
      return k if v.include? ext
    end
    nil
  end

  def initialize(source)
    init(source.to_s)
  end

  def convert(target, format = nil)
    do_convert(target, format)
  end
  
  def support_mimetype?(mimetype)
    @type2mime_map.has_value? mimetype
  end
  
  def support_extension?(extension)
    ext2type extension
  end
  
  protected

  def load_config(file)
    @type2mime_map = {}
    @type2ext_map = {}
    @type2options_map = {}

    config = YAML.load_file file
    @media_type = config[:MEDIA]
    config[:TYPES].each do |t|
      type = t[:TYPE]
      @type2mime_map[type] = t[:MIME]
      @type2ext_map[type]  = t[:EXTENSIONS].split(',')
      t.delete(:TYPE)
      t.delete(:MIME)
      t.delete(:EXTENSIONS)
      @type2options_map[type] = t
    end
  end

end
