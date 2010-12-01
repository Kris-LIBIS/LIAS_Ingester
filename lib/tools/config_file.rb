class ConfigFile

  FILENAME = 'config.yml'

  @config = {}      
 
  def self.[](key)
    init
    @config[key]
  end
  
  private
  
  def self.init
    return unless @config.empty?
    dir = File.dirname(__FILE__) + '/../..'
    dir = File.absolute_path(dir)
    @config = YAML::load_file(dir + '/' + FILENAME)
    if File.exist?(FILENAME)
      local_config = {}
      local_config = YAML::load_file(FILENAME)
      @config.merge!(local_config)
    end
  end
end
