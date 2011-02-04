require 'rubygems'
require 'singleton'
require 'logger'
require 'optparse'

require 'lib/tools/database'
#require 'lib/models/common/status'
require 'lib/modules/initializer'
require 'lib/modules/pre_processor'
require 'lib/modules/pre_ingester'
require 'lib/modules/ingester'
require 'lib/modules/post_ingester'

class Application
  include Singleton

  attr_reader :logger
  attr_reader :db_log_level
  attr_accessor :log_objects
  attr_reader :log_file
  attr_reader :options
  attr_accessor :flush_counter

  def self.dir
    "#{File.dirname(__FILE__)}/.."
  end

  def self.log_to(obj)
    return if obj.nil?
    self.instance.log_objects << obj
  end

  def self.log_end(obj)
#    obj.save unless obj.nil?
    return false if self.instance.log_objects.empty?
    return (obj == self.instance.log_objects.pop) if (obj == nil or self.instance.log_objects[-1] == obj)
    false
  end
  
  def set_action(action,start)
    if @options[:action] then
      puts "ERROR: options --start, --continue, --restart and --undo are mutually exclusive."
      exit
    end
    @options[:action] = action
    @options[:start] = start
  end

  def initialize
    @options = {}
    
    begin
    
    OptionParser.new do |opts|
      
      opts.banner = "Usage: #{$0} [options] <configuration_file|id> ..."
      opts.separator ""
      opts.separator "Options:"
      opts.separator('  module numbers: 1 = initializer, 2 = preprocessor, 3 = preingester,  4 = ingester, 5 = postingester')
      
      
      opts.on_tail('-h', '--help', 'Show this help info') do
        puts opts
        exit
      end
      
      opts.on('--start N', 'Start the module for a run/configuration', Integer) do |data|
        set_action :start, data
      end
      
      opts.on('--continue N', 'Continue the module for a run/configuration', Integer) do |data|
        set_action :continue, data
      end
      
      opts.on('--restart N', 'Restart the module for a run/configuration', Integer) do |data|
        set_action :restart, data
      end
      
      opts.on('--undo N', 'Undo the module for a run/configuration', Integer) do |data|
        set_action :undo, data
      end
      
      @options[:end] = 99
      opts.on('--end N', 'End processing at this module', Integer) do |data|
        @options[:end] = data
      end
      
      @options[:config_file] = './config.yml'
      opts.on('-c', '--config_file FILE', "Use FILE instead of '#{@options[:config_file]}'") do |file|
        @options[:config_file] = file
      end
      
      @options[:log_file] = nil
      opts.on('-l', '--log_file FILE', 'Write all logging to FILE') do |file|
        @options[:log_file] = file
      end
      
      @options[:log_level] = nil
      opts.on('-v', '--log_level N', 'Set the logging level', Integer,
              '  0: DEBUG, 1: INFO (default), 2: WARN, 3: ERROR, 4: FATAL') do |level|
        @options[:log_level] = level
      end
      
    end.parse!
    
    rescue OptionParser::ParseError => ex
      puts "Error parsing command-line input: '#{ex.message}'"
      puts "Use option '-h' to get help."
      exit
      
    rescue Exception => ex
      puts "ERROR: #{ex.message}" unless ex.message == 'exit'
      exit
    end
    
  end
  
  def init
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    @database = Database.new
    @log_objects = Array.new
    @logger.formatter = proc { |severity, datetime, progname, msg|
      @logger.db_logger(severity, datetime, progname, msg)
    }
    
    @logger.level = ConfigFile['log_level'] || 1
    @logger.level = options[:log_level] if options[:log_level]
    
    @db_log_level = ConfigFile['log_to_db_level'] || 2
    @db_log_level = options[:db_log_level] if options[:db_log_level]
    
    @log_file = ConfigFile['log_file'] || nil
    @log_file = options[:log_file] if options[:log_file]
    
    @log_file = File.open(@log_file,'w:utf-8') if @log_file
    
    @flush_counter = 0
  end

  def terminate
    @logger.close
    @log_file.close if @log_file
  end
  
  def self.write_log(severity, datetime, progname, msg)
    return unless self.instance.log_file
    self.instance.log_file.puts "[#{datetime.to_s}] #{severity} -- #{progname}: #{msg}"
    self.instance.flush_counter = self.instance.flush_counter + 1
    self.instance.log_file.flush if self.instance.flush_counter > 10
    self.instance.flush_counter = 0 if self.instance.flush_counter > 10
  end

  def self.send_log(severity, datetime, progname, msg)
    entry = LogEntry.new(:severity => severity, :created_at => datetime,
                         :program => progname, :message => msg)
    unless self.instance.log_objects.nil?
      self.instance.log_objects.each do |obj|
        obj.log_entries << entry
      end
    end
  end

  def self.debug(progname = nil, &block)
    self.instance.logger.db_log = (::Logger::DEBUG >= self.instance.db_log_level)
    self.instance.logger.debug(progname,&block)
  end

  def self.info(progname = nil, &block)
    self.instance.logger.db_log = (::Logger::INFO  >= self.instance.db_log_level)
    self.instance.logger.info(progname,&block)
  end

  def self.warn(progname = nil, &block)
    self.instance.logger.db_log = (::Logger::WARN  >= self.instance.db_log_level)
    self.instance.logger.warn(progname,&block)
  end

  def self.error(progname = nil, &block)
    self.instance.logger.db_log = (::Logger::ERROR >= self.instance.db_log_level)
    self.instance.logger.error(progname,&block)
  end

  def self.fatal(progname = nil, &block)
    self.instance.logger.db_log = (::Logger::FATAL >= self.instance.db_log_level)
    self.instance.logger.fatal(progname,&block)
  end

  def self.assert(*msg)
    raise "Assertion failed! #{msg}" unless yield if $DEBUG
  end

end

class Logger
  attr_accessor :db_log

  def db_logger(severity, datetime, progname, msg)
    ::Application.write_log(severity, datetime, progname, msg)
    ::Application.send_log(severity, datetime, progname, msg) if @db_log
    @default_formatter.call(severity, datetime, progname, msg)
  end
end

# to force initialization of the database
@@app = Application.instance
@@app.init
@@logger = @@app.logger
