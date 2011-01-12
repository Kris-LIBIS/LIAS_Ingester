require 'dm-core'
require 'dm-types'
require 'dm-timestamps'
require 'lib/tools/hash'
require File.dirname(__FILE__) + '/bad_config_exception'
require File.dirname(__FILE__) + '/status'

module CommonConfig

  def self.included(receiver)

    receiver.class_eval do

      property    :id,              DataMapper::Property::Serial, :key => true
      property    :created_at,      DataMapper::Property::DateTime
      property    :updated_at,      DataMapper::Property::DateTime

      # flow info
      property    :check_virus1,    DataMapper::Property::Boolean
      property    :check_checksum1, DataMapper::Property::Boolean
      property    :check_ingested1, DataMapper::Property::Boolean
      property    :work_dir1,       DataMapper::Property::String

      # checksum info
      property    :checksum_type1,  DataMapper::Property::Enum[:MD5, :SHA1, :SHA256, :SHA384, :SHA512]
      property    :checksum_file1,  DataMapper::Property::String

      # metadata info
      property    :metadata_file1,  DataMapper::Property::String
      property    :search_target,   DataMapper::Property::String
      property    :search_host,     DataMapper::Property::String
      property    :search_index,    DataMapper::Property::String
      property    :search_base,     DataMapper::Property::String
      property    :search_match,    DataMapper::Property::Regexp
      property    :search_term,     DataMapper::Property::String

      # contol fields
      property    :control_fields,  DataMapper::Property::Yaml, :length => 2000

      def common_config(config, apply_defaults = true)

        if apply_defaults
          self.check_virus1     = true
          self.check_checksum1  = true
          self.check_ingested1  = false
          self.checksum_type1   = :MD5
          self.checksum_file1   = 'MD5/md5sums.txt'
          self.metadata_file1   = nil
          self.search_target    = 'Opac'
          self.search_host      = 'http://opac.libis.be/X'
          self.search_index     = 'sig'
          self.search_base      = 'KADOC'
          self.search_match     = nil
          self.search_term      = nil
          self.control_fields   = '[]'
        end

        return unless config

        config.key_strings_to_symbols!

        config.each do |label,content|
          next unless content
          case label
          when :pre_process
            content.key_strings_to_symbols!
            content.each do |k,v|
              case k
              when :check_virus
                self.check_virus1     = v
              when :check_checksum
                self.check_checksum1  = v
              when :check_ingested
                self.check_ingested1  = v
              else
                Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
              end
            end

          when :pre_ingest
            content.key_strings_to_symbols!
            content.each do |k,v|
              case k
              when :work_dir
                self.work_dir1        = v
              else
                Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
              end
            end

          when :ingest
            content.key_strings_to_symbols!
            content.each do |k,v|
              Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
            end

          when :post_ingest
            content.key_strings_to_symbols!
            content.each do |k,v|
              Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
            end

          when :checksum
            content.key_strings_to_symbols!
            content.each do |k,v|
              case k
              when :type
                self.checksum_type1  = Checksum.type_from_string(v)
              when :file
                self.checksum_file1  = v
              else
                Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
              end
            end

          when :metadata
            content.key_strings_to_symbols!
            content.each do |k,v|
              case k
              when :target
                self.search_target  = v
              when :host
                self.search_host    = v
              when :index
                self.search_index   = v
              when :base
                self.search_base    = v
              when :match
                self.search_match   = v
              when :term
                self.search_term    = v
              when :file
                self.metadata_file1 = v
              else
                Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
              end
            end

          when :control_fields
            self.control_fields     = content

          when :accessrights
            content.each do |k,v|
              prot = Protection.from_value(v)
              prot.usage_type = k.upcase
              self.protections << prot
            end

          end # case

        end # config.each

      end # common_config()

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

      def get_search_options
        result = Hash.new
        result.merge self.ingest_run.get_search_options if self.respond_to? :ingest_run and self.ingest_run
        result[:host]   = self.search_host    if self.search_host
        result[:target] = self.search_target  if self.search_target
        result[:base]   = self.search_base    if self.search_base
        result[:index]  = self.search_index   if self.search_index
        result[:match]  = self.search_match   if self.search_match
        result[:term]   = self.search_term    if self.search_term
        result
      end

      def get_control_fields
        result = Hash.new
        result.merge! self.ingest_run.control_fields if self.respond_to? :ingest_run and self.ingest_run and self.ingest_run.control_fields
        result.merge! self.control_fields if self.control_fields
        result
      end

      def get_protection(usage_type)
        self.protections.each do |p|
          return p if p.usage_type == usage_type
        end
        return self.ingest_run.get_protection(usage_type) if self.respond_to? :ingest_run and self.ingest_run
        nil
      end

      def get_protections
        result = {}
        result = self.ingest_run.get_protections if self.respond_to? :ingest_run and self.ingest_run
        self.protections.each do |p|
          result[p.usage_type] = p
        end
        result
      end

      def get_objects
        self.ingest_objects.all(:parent => nil)
      end

    end
  end
end

