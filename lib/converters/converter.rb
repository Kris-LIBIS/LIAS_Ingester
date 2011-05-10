require_relative '../tools/string'

class Converter

  @@converters = []

  #noinspection RubyResolve
  def Converter.get_converters
    if @@converters.empty?
      Dir.glob("#{Application.dir}/lib/converters/*_converter.rb").each do |f|
        require_relative File.basename(f, '.rb')
      end
    end
    @@converters
  end

  def initialize(source)
    init(source.to_s)
  end

  def convert(target, format = nil)
    do_convert(target, format)
  end

  attr_reader :converters

  def Converter.inherited( klass )

    @@converters << klass

    klass.class_eval {

      def self.media_type
        class_variable_get :@@media_type
      end

      def self.type2mime_map
         class_variable_get :@@type2mime_map
      end

      def self.type2ext_map
         class_variable_get :@@type2ext_map
      end

      def self.type2options_map
         class_variable_get :@@type2options_map
      end

      def self.type2mime(t)
        type2mime_map[t]
      end

      def self.type2ext(t)
        type2ext_map[t].first
      end

      def self.mime2type(mime)
        type2mime_map.invert[mime]
      end

      def self.ext2type(ext)
        type2ext_map.each do |k,v|
          return k if v.include? ext
        end
        nil
      end

      def self.support_mimetype?(mimetype)
        type2mime_map.has_value? mimetype
      end

      def self.support_extension?(extension)
        ext2type extension
      end

      def self.load_config(file)
        my_type2mime_map = {}
        my_type2ext_map = {}
        my_type2options_map = {}

        config = YAML.load_file file
        my_media_type = config[:MEDIA]
        config[:TYPES].each do |t|
          type = t[:TYPE]
          my_type2mime_map[type] = t[:MIME]
          my_type2ext_map[type]  = t[:EXTENSIONS].split(',')
          t.delete(:TYPE)
          t.delete(:MIME)
          t.delete(:EXTENSIONS)
          my_type2options_map[type] = t
        end
        class_variable_set :@@media_type, my_media_type
        class_variable_set :@@type2mime_map, my_type2mime_map
        class_variable_set :@@type2ext_map, my_type2ext_map
        class_variable_set :@@type2options_map, my_type2options_map
      end
    }

    klass.class_exec(Application.dir + '/config/converters/' + klass.to_s.underscore + '.yaml') { |file|
      klass.load_config(file)
    }

  end


end
