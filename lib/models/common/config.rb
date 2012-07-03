# coding: utf-8

require 'dm-core'
require 'dm-types'
require 'dm-timestamps'

require 'tools/hash'
require 'accessright_models/accessright_model_dispatcher'

require_relative 'bad_config_exception'
require_relative 'status'

#noinspection RubyResolve
module CommonConfig

  def self.included(receiver)

    receiver.class_eval do

      property :id, DataMapper::Property::Serial, :key => true
      property :created_at, DataMapper::Property::DateTime
      property :updated_at, DataMapper::Property::DateTime

      # preprocess
      property :check_virus1, DataMapper::Property::Boolean
      property :check_checksum1, DataMapper::Property::Boolean
      property :check_ingested1, DataMapper::Property::Boolean

      # preingest
      property :work_dir1, DataMapper::Property::String

      # postprocess
      property :link_type, DataMapper::Property::Enum[:CollectiveAccess]
      property :link_options, DataMapper::Property::Yaml, :length => 2000

      # checksum info
      property :checksum_type1, DataMapper::Property::Enum[:MD5, :SHA1, :SHA256, :SHA384, :SHA512]
      property :checksum_file1, DataMapper::Property::String

      # metadata info
      property :metadata_file1, DataMapper::Property::String
      property :metadata_format1, DataMapper::Property::Enum[:DC, :MARC21]
      property :search_target, DataMapper::Property::String
      property :search_host, DataMapper::Property::String
      property :search_index, DataMapper::Property::String
      property :search_base, DataMapper::Property::String
      property :search_match, DataMapper::Property::Regexp
      property :search_term, DataMapper::Property::String
      property :metadata_fields, DataMapper::Property::Yaml, :length => 2000

      # contol fields
      property :control_fields, DataMapper::Property::Yaml, :length => 2000

      # accessright model fields
      property :ar_model_data, DataMapper::Property::Yaml, :length => 2000

      def common_config(config, apply_defaults = true)

        if apply_defaults
          self.check_virus1 = true
          self.check_checksum1 = true
          self.check_ingested1 = false
          self.checksum_type1 = :MD5
          self.checksum_file1 = 'MD5/md5sums.txt'
          self.metadata_file1 = nil
          self.search_target = 'Opac'
          self.search_host = 'http://opac.libis.be/X'
          self.search_index = 'sig'
          self.search_base = 'KADOC'
          self.search_match = nil
          self.search_term = nil
          self.link_type = nil
          self.link_host = nil
        end

        self.metadata_fields = {}
        self.control_fields = {}
        self.ar_model_data = {}

        return unless config

        config.key_strings_to_symbols! :downcase => true

        config.each do |label, content|
          next unless content
          case label
            when :pre_process
              content.key_strings_to_symbols! :downcase => true
              content.each do |k, v|
                case k
                  when :check_virus
                    self.check_virus1 = v
                  when :check_checksum
                    self.check_checksum1 = v
                  when :check_ingested
                    self.check_ingested1 = v
                  else
                    Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
                end
              end

            when :pre_ingest
              content.key_strings_to_symbols! :downcase => true
              content.each do |k, v|
                case k
                  when :work_dir
                    self.work_dir1 = v
                  else
                    Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
                end
              end

            when :ingest
              content.key_strings_to_symbols! :downcase => true
              content.each do |k, _|
                Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
              end

            when :post_ingest
              content.key_strings_to_symbols! :downcase => true
              content.each do |k, _|
                Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
              end

            when :post_process
              content.key_strings_to_symbols! :downcase => true
              content.each do |k, v|
                case k
                  when :add_link
                    v.key_strings_to_symbols! :downcase => true
                    v.each do |k1, v1|
                      case k1
                        when :type
                          self.link_type = v1.to_sym
                        when :options
                          self.link_options = v1
                        else
                          Application.warn('Configuration') { "Ongekende optie '#{k1.to_s}' opgegeven in sectie '#{k.to_s}'" }
                      end # case k1
                    end # v.each

                  else
                    Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
                end
              end

            when :checksum
              content.key_strings_to_symbols! :downcase => true
              content.each do |k, v|
                case k
                  when :type
                    self.checksum_type1 = Checksum.type_from_string(v)
                  when :file
                    self.checksum_file1 = v
                  else
                    Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
                end
              end

            when :metadata
              content.key_strings_to_symbols! :downcase => true
              content.each do |k, v|
                case k
                  when :target
                    self.search_target = v
                  when :host
                    self.search_host = v
                  when :index
                    self.search_index = v
                  when :base
                    self.search_base = v
                  when :match
                    self.search_match = Regexp.new(v)
                  when :term
                    self.search_term = v
                  when :file
                    self.metadata_file1 = v
                  when :format
                    self.metadata_format1 = v.to_sym
                  when :fields
                    self.metadata_fields = v
                  else
                    Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
                end
              end

            when :control_fields
              self.control_fields = content

            when :accessrights
              self.ar_model_data[:custom] = content.key_strings_to_symbols!(upcase: true)

            when :accessright_model
              self.ar_model_data[:model_name] = content.to_s

            when :accessright_model_map
              self.ar_model_data[:model_map] = content.to_s

            else

          end # case

        end # config.each

      end

      # common_config()

      def get_ar_model_data(key)
        return self.ar_model_data[key] if self.ar_model_data and self.ar_model_data.has_key? key
        return self.ingest_run.get_ar_model_data(key) if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def get_ar_model_dispatcher
        @ar_model_dispatcher ||= AccessrightModelDispatcher.new("#{self.class.name}_##{self.id}",
            get_ar_model_data(:model_map), get_ar_model_data(:model_name), get_ar_model_data(:custom))
      end

      def get_accessright_model(obj = nil)
        dispatcher = get_ar_model_dispatcher
        return nil unless dispatcher
        dispatcher.get_accessright_model(obj)
      end

      def get_accessrights(obj = nil)
        ar_model = get_accessright_model(obj)
        return nil unless ar_model
        ar_model.get_accessrights
      end

      def get_accessright(usage_type, obj = nil)
        ar_model = get_accessright_model(obj)
        return nil unless ar_model
        ar_model.get_accessright(usage_type)
      end

      def check_virus
        return self.check_virus1 unless self.check_virus1.nil?
        return self.ingest_run.check_virus1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def check_checksum
        return self.check_checksum1 unless self.check_checksum1.nil?
        return self.ingest_run.check_checksum1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def check_ingested
        return self.check_ingested1 unless self.check_ingested1.nil?
        return self.ingest_run.check_ingested1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def work_dir
        return self.work_dir1 unless self.work_dir1.nil?
        return self.ingest_run.work_dir1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def checksum_type
        return self.checksum_type1 unless self.checksum_type1.nil?
        return self.ingest_run.checksum_type1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def checksum_file
        return self.checksum_file1 unless self.checksum_file1.nil?
        return self.ingest_run.checksum_file1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def metadata_file
        return self.metadata_file1 unless self.metadata_file1.nil?
        return self.ingest_run.metadata_file1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def metadata_format
        return self.metadata_format1 unless self.metadata_format1.nil?
        return self.ingest_run.metadata_format1 if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def get_search_options
        result = Hash.new
        result.merge self.ingest_run.get_search_options if self.respond_to? :ingest_run and self.ingest_run
        result[:host] = self.search_host if self.search_host
        result[:target] = self.search_target if self.search_target
        result[:base] = self.search_base if self.search_base
        result[:index] = self.search_index if self.search_index
        result[:match] = self.search_match if self.search_match
        result[:term] = self.search_term if self.search_term
        result
      end

      def get_metadata_fields
        result = Hash.new
        result.merge! self.ingest_run.metadata_fields if self.respond_to? :ingest_run and self.ingest_run and self.ingest_run.metadata_fields
        result.merge! self.metadata_fields if self.metadata_fields
        result
      end

      def get_control_fields
        result = Hash.new
        result.merge! self.ingest_run.control_fields if self.respond_to? :ingest_run and self.ingest_run and self.ingest_run.control_fields
        result.merge! self.control_fields if self.control_fields
        result
      end

      def get_objects
        self.ingest_objects.all(:parent => nil)
      end

      def get_link_type
        return self.link_type unless self.link_type.nil?
        return self.ingest_run.link_type if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def get_link_options
        return self.link_options unless self.link_options.nil?
        return self.ingest_run.link_options if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

    end
  end
end

