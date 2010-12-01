require File.dirname(__FILE__) + '/common/config'
require File.dirname(__FILE__) + '/common/status'

class IngestConfig
  include DataMapper::Resource
  include CommonConfig

  property    :status,          Integer, :default => Status::New

  # file selection criteria
  property    :filename_match,  Regexp
  property    :mime_type,       Regexp

  # ingest options
  property    :ingest_model,    String
  property    :media_type,      Enum[:IMAGE, :DOCUMENT, :ARCHIVE, :CONTAINER, :AUDIO, :VIDEO]
  property    :quality,         Enum[:ARCHIVE, :HIGH, :LOW]

  # complex options
  property    :complex,         Boolean
  property    :complex_group,   String
  property    :complex_label,   String
  property    :complex_utype,   String

  # ingest info
  property    :ingest_id,       String
  property    :ingest_dir,      String
  property    :tasker_log,      Text

  belongs_to  :ingest_run, :required => false

  has n,      :protections, :child_key => :ingest_config_id
  has n,      :ingest_objects, :child_key => :ingest_config_id

  has n,      :log_entries, :child_key => :ingest_config_id

  before :destroy do
    self.ingest_object.destroy
    self.protections.destroy
    self.log_entries.destroy
    true
  end

  public

  def init(config)

    config.key_strings_to_symbols!

    # common configuration
    common_config(config, false)

    # ingest_config specific configuration
    
    self.filename_match   = Regexp.new('')
    self.mime_type        = Regexp.new('')
#    self.ingest_model     = 'default'
#    self.media_type       = :IMAGE
#    self.quality          = :ARCHIVE
    self.complex          = false
#    self.complex_group    = ''
#    self.complex_label    = ''
    self.complex_utype    = 'VIEW_MAIN'
#    self.ingest_id        = ''
#    self.ingest_dir       = ''
   
    config.each do |label,value|
      case label
      when :match
        self.filename_match = value
      when :mime_type
        self.mime_type      = value
      when :ingest_model
        value.key_strings_to_symbols!
        value.each do |k,v|
          case k
          when :model
            self.ingest_model   = v
          when :media_type
            self.media_type     = v.to_s.upcase.to_sym
          when :quality
            self.quality        = v.to_s.upcase.to_sym
          end # case k
        end # value.each
      when :complex
        self.complex        = true
        value.key_strings_to_symbols!
        self.complex_group  = value[:group]
        self.complex_label  = value[:label]
        self.complex_utype  = value[:usage_type].upcase if value[:usage_type]
        if value[:accessright]
          prot = Protection.from_value(value[:accessright])
          prot.usage_type = 'COMPLEX_' + self.complex_utype
          self.protections << prot
        end
      end # case label
    end # config.each

  end

  def root_object(label)
    root = root_objects.first(:label => label)
    unless root
      root = IngestObject.new
      root.usage_type = self.complex_utype
      root.label = label
      root.status = Status::PreProcessed
      add_object root
      save
    end
    root
  end

  def root_objects
    self.ingest_objects.all(:parent => nil, :master => nil)
  end

  def add_object( obj )
    self.ingest_objects << obj
    obj.ingest_config = self
  end

  def del_object( obj )
    self.ingest_objects.delete obj
    obj.ingest_config = nil
  end

  def check_object_status( status )
    ingest_objects.each do |obj|
      return false if obj.status < status
    end
    true
  end

  def debug_print( indent = 0 )
    p ' ' * indent + self.inspect
    indent += 2
    self.protections.each     { |p| p.debug_print indent }
    self.ingest_objects.each  { |o| o.debug_print indent }
  end

end
