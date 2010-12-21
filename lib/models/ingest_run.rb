require File.dirname(__FILE__) + '/common/config'
require File.dirname(__FILE__) + '/common/status'

class IngestRun
  include DataMapper::Resource
  include CommonConfig

  property    :status,          Integer, :default => Status::New
  property    :init_end,        DateTime

  # config file info
  property    :config_file,     String
  property    :checksum,        String
  property    :mtime,           DateTime

  # packaging info
  property    :packaging,       Enum[:DIR, :ZIP, :RAR, :TAR, :TGZ, :TBZ]
  property    :location,        String
  property    :recursive,       Boolean
  property    :selection,       Regexp

  has n,      :protections, :child_key => :ingest_run_id
  has n,      :ingest_objects, :child_key => :ingest_run_id

  has n,      :ingest_configs

  has n,      :log_entries, :child_key => :ingest_run_id

  before :destroy do
    self.ingest_configs.destroy
    self.ingest_objects.destroy
    self.protections.destroy
    self.log_entries.destroy
    true
  end

  def init(config_file)

    unless (File::exists?(config_file))
      @status     = Status::Failed
      raise BadConfigException.new("Configuratiebestand #{config_file} kan niet gevonden worden")
      return
    end

    # config file info
    self.config_file    = config_file
    self.checksum       = Digest::MD5.hexdigest(File.read(config_file))
    self.mtime          = File.mtime(config_file)

    config              = YAML::load_file(config_file)
    config.key_strings_to_symbols! :downcase => true

    # common configuration
    common_config(config[:common])

    # ingest_run specific configuration

    self.packaging      = :DIR
    self.location       = '.'
    self.recursive      = false
    self.selection      = Regexp.new(/.*/)

    if config[:common]
      config[:common].key_strings_to_symbols!
      config[:common].each do |k,v|
        case k
        when :packaging
          v.key_strings_to_symbols!
          v.each do |k,v|
            case k
            when :type
              self.packaging  = v.upcase.to_sym
            when :location
              self.location   = v
            when :recursive
              self.recursive  = v
            when :selection
              self.selection  = v
            else
              Application.warn('Configuration') { "Ongekende optie '#{k.to_s}' opgegeven in sectie '#{label.to_s}'" }
            end # case
          end # v.each
        end # case
      end # config[:common].each
    end # if config[:common]

    begin
      config[:configurations].each do |c|
        config = IngestConfig.new
        config.init(c)
        self.ingest_configs << config
      end
    rescue BadConfigException
      self.status       = Status::Failed
      raise
    end 

  end

  def add_object( object )
    self.ingest_objects << object
    object.ingest_run = self
  end

  def del_object( object )
    self.ingest_objects.delete object
    object.ingest_run = nil
  end

  def debug_print( indent = 0 )
    p ' ' * indent + self.inspect
    indent += 2
    self.protections.each     { |p| p.debug_print indent }
    self.ingest_configs.each  { |c| c.debug_print indent }
    self.ingest_objects.each  { |o| o.debug_print indent }
  end

end
