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
    filename = Application.instance.options[:config_file] || FILENAME
    if File.exist?(filename)
      local_config = YAML::load_file(filename)
      @config.merge!(local_config)
    end
  end
end
