# coding: utf-8

require_relative 'common/config'
require_relative 'common/status'

#noinspection RubyResolve
class IngestConfig
  include DataMapper::Resource
  include CommonConfig

  property    :status,                Integer, :default => Status::New
  property    :status_name,           String

  # file selection criteria
  property    :filename_match,        Regexp
  property    :mime_type,             Regexp

  # ingest options
  property    :ingest_model,          String
  property    :ingest_model_map,      String
  property    :manifestations_config, Yaml
  property    :media_type,            String
  property    :quality,               String

  # complex options
  property    :complex,               Boolean
  property    :complex_group,         String
  property    :complex_label,         String
  property    :complex_utype,         String

  # mets options
  property    :mets,                  Boolean

  # ingest info
  property    :ingest_id,             String
  property    :ingest_dir,            String
  property    :tasker_log,            Text

  belongs_to  :ingest_run,            :required => false

  has n,      :ingest_objects,        :child_key => :ingest_config_id

  has n,      :log_entries,           :child_key => :ingest_config_id

  before :destroy do
    self.root_objects.each { |o| o.delete }
    self.ingest_objects.clear
    self.log_entries.destroy
    true
  end

  after :status= do
    self.status_name = Status.to_string(self.status)
  end

  public

  def init(config)

    config.key_strings_to_symbols! :downcase => true

    # common configuration
    common_config(config, false)

    # ingest_config specific configuration
    self.filename_match = Regexp.new('')
    self.mime_type = Regexp.new('')
    self.complex = false
    self.complex_utype = 'COMPLEX_VIEW_MAIN'
    self.mets = false
    self.manifestations_config = {}

    config.each do |label, value|
      case label
        when :match
          self.filename_match = Regexp.new(value)
        when :mime_type
          self.mime_type = Regexp.new(value)
        when :ingest_model
          value.key_strings_to_symbols! :downcase => true
          value.each do |k, v|
            case k
              when :file
                self.ingest_model_map = v
              when :model
                self.ingest_model = v
              when :media_type
                self.media_type = v.to_s.upcase
              when :quality
                self.quality = v.to_s.upcase
              when :manifestations
                v.each { |c| c.key_strings_to_symbols! :upcase => true, :recursive => true }
                self.manifestations_config = v
              else
            end # case k
          end # value.each
        when :complex
          self.complex = true
          value.key_strings_to_symbols! :downcase => true
          self.complex_group = value[:group]
          self.complex_label = value[:label]
          self.complex_utype = 'COMPLEX_' + value[:usage_type].upcase if value[:usage_type]
          if value[:accessright]
            self.ar_model_data[:custom][self.complex_utype.to_sym] = value[:accessright]
          end
        when :mets
          self.mets = true
          if value
            value.key_strings_to_symbols! :downcase => true
            self.complex_group = value[:group]
            self.complex_label = value[:label]
            self.complex_utype = 'COMPLEX_' + value[:usage_type].upcase if value[:usage_type]
            if value[:accessright]
              self.ar_model_data[:custom][self.complex_utype.to_sym] = value[:accessright]
            end
          end
        else
      end # case label
    end # config.each

  end

  def get_media_type
    self.media_type.to_s.upcase.to_sym
  end

  def get_quality
    self.quality.to_s.upcase.to_sym
  end

  def get_ingest_model_dispatcher
    @ingest_model_dispatcher ||= IngestModelDispatcher.new("#{self.class.name}_##{self.id}", self.ingest_model_map,
                                                           self.ingest_model, get_media_type, get_quality,
                                                           self.manifestations_config)
  end

  def get_ingest_model(obj = nil)
    dispatcher = get_ingest_model_dispatcher
    return nil unless dispatcher
    dispatcher.get_ingest_model(obj)
  end

  def get_or_create_object(label)
    label = [label] unless label.kind_of? Array
    parent = nil
    label.each { |l| parent = get_or_create_child_object parent, l }
    parent
  end

  def get_or_create_child_object(parent, label)
    lookup_pool = (parent ? parent.children : root_objects)
    found = lookup_pool.first :label_name => label
    unless found
      found = IngestObject.new
      found.usage_type = self.complex_utype
      found.label = label
      found.status = Status::PreProcessed
      add_object found
      found.parent = parent
      found.save
    end
    found
  end

  def root_objects
    self.ingest_objects.all(:parent => nil, :master => nil)
  end

  def add_object(obj)
    self.ingest_objects << obj
  end

  def del_object(obj)
    obj.ingest_config = nil
  end

  def check_object_status(status)
    self.ingest_objects.each do |obj|
      return false if obj.status < status
    end
    true
  end

  def debug_print(indent = 0)
    p ' ' * indent + self.inspect
    indent += 2
    self.ingest_objects.each { |o| o.debug_print indent }
  end

end
