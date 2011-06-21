require_relative 'common/config'
require_relative 'common/status'

#noinspection RubyResolve
class IngestRun
  include DataMapper::Resource
  include CommonConfig

  property    :status,          Integer, :default => Status::New
  property    :status_name,     String
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
  
  after :status= do
    self.status_name = Status.to_string(self.status)
  end

  public
  
  def reset
    self.ingest_configs.destroy
    self.ingest_objects.destroy
    self.protections.destroy
    self.log_entries.destroy
  end

  def init(config_file)

    unless (File::exists?(config_file))
      @status     = Status::Failed
      raise BadConfigException.new("Configuratiebestand '#{config_file}' kan niet gevonden worden", nil)
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
      config[:common].key_strings_to_symbols! :downcase => true
      config[:common].each do |k1,v1|
        case k1
        when :packaging
          v1.key_strings_to_symbols! :downcase => true
          v1.each do |k2,v2|
            case k2
            when :type
              self.packaging  = v2.upcase.to_sym
            when :location
              self.location   = v2
            when :recursive
              self.recursive  = v2
            when :selection
              self.selection  = Regexp.new(v2)
            else
              Application.warn('Configuration') { "Ongekende optie '#{k2.to_s}' opgegeven in sectie '#{label.to_s}'" }
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
#    object.ingest_run = self
  end

  def del_object( object )
#    self.ingest_objects.delete object
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
