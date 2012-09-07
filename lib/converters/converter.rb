# coding: utf-8

require 'tools/string'
require 'ingester_task'

require_relative 'type_database'

#noinspection RubyClassVariableUsageInspection
class Converter
  include IngesterTask

  public

  def initialize(source)
    init(source.to_s)
  end

  def convert(target, format = nil)
    do_convert(target, format)
  end


  def Converter.inherited( klass )

    ConverterRepository.register klass

    klass.class_eval {

      def self.config_file
        Application.dir + '/config/converters/' + self.name.underscore + '.yaml'
      end

      def self.input_type?(type_id)
        self.input_types_list.include? type_id
      end

      def self.output_type?(type_id)
        self.output_types_list.include? type_id
      end

      def self.input_mimetype?(mimetype)
        type_id = TypeDatabase.instance.mime2type mimetype
        self.input_type? type_id
      end

      def self.output_mimetype?(mimetype)
        type_id = TypeDatabase.instance.mime2type mimetype
        self.output_type? type_id
      end

      def self.conversion?(input_type, output_type)
        self.conversions[input_type] and self.conversions[input_type].any? { |t| t == output_type }
      end

      def self.output_types(input_type)
        self.conversions[input_type]
      end

      def self.extension?(extension)
        ext2type extension
      end

      def self.load_config

        file = self.config_file
        config = YAML.load_file file
        config.key_strings_to_symbols! upcase: true, recursive: true

        my_input_types = []
        my_output_types = []

        config[:TYPES].each do |t|
          my_input_types << t
          my_output_types << t
        end if config[:TYPES]

        config[:INPUT_TYPES].each do |t|
          my_input_types << t
        end if config[:INPUT_TYPES]

        config[:OUTPUT_TYPES].each do |t|
          my_output_types << t
        end if config[:OUTPUT_TYPES]

        class_variable_set :@@input_types, my_input_types
        class_variable_set :@@output_types, my_output_types

        my_conversions = nil
        my_conversions = config[:CONVERSIONS] if config[:CONVERSIONS]
        unless my_conversions
          my_conversions = {}
          my_input_types.each do |input|
            my_conversions[input] = my_output_types
          end
        end
        class_variable_set :@@conversions, my_conversions
      end

      def initialize( source = nil, options = {}, flags = {} )
        init(source) if source
        @options ||= {}
        @options.merge! options if options
        @flags ||= {}
        @flags.merge! flags if flags
      end

      private

      def self.input_types_list
        class_variable_get :@@input_types
      end

      def self.output_types_list
        class_variable_get :@@output_types
      end

      def self.conversions
        class_variable_get :@@conversions
      end

    }

  end


end
