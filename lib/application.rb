# coding: utf-8

$: << File.expand_path(File.dirname(__FILE__))

require 'rubygems'
require 'singleton'
require 'logger'
require 'optparse'

require 'application_status'
require 'tools/database'
require 'modules/pre_processor'
require 'modules/pre_ingester'
require 'modules/ingester'
require 'modules/post_ingester'

# Makes our life much easier
def nil.each #(&block)
end

#flush stdout output immediately
$stdout.sync = true

class Application
  include Singleton

  #noinspection RubyResolve
  attr_reader   :logger
  #noinspection RubyResolve
  attr_accessor :db_log_level
  #noinspection RubyResolve
  attr_accessor :log_objects
  #noinspection RubyResolve
  attr_reader   :log_file
  #noinspection RubyResolve
  attr_reader   :options
  #noinspection RubyResolve
  attr_accessor :flush_counter

  def self.dir
    File.expand_path "#{File.dirname(__FILE__)}/.."
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
  
  def set_action(action, module_id)
    if @options[:action] then
      puts "ERROR: options --start, --continue, --restart and --undo are mutually exclusive."
      exit
    end
    @options[:action] = action
    @options[:module_id] = module_id
  end

  def initialize
    @options = {}
    
    begin
    
    OptionParser.new do |opts|
      
      opts.banner = "Usage: #{$0} [options] <configuration_file|id|selection> ..."
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

      opts.on('--sharepoint_metadata F', 'The file containing the SharePoint metadata') do |file|
        @options[:sharepoint_metadata] = file
      end

      opts.on('--sharepoint_datadir D', 'Location of the downloaded SharePoint data') do |dir|
        @options[:sharepoint_datadir] = dir
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

      @options[:log_buffer] = 20
      opts.on('-b', '--log_buffer N', 'Set the logging buffer', Integer,
              '  0: buffer off, n>0: buffer n lines before flusing the log file (default = 20)') do |buffer_size|
        if buffer_size <= 0
          #noinspection RubyArgCount
          self.class.class_eval do
            def flush_log
              @log_file.flush
            end
          end
        end
        @options[:log_buffer] = buffer_size
      end

      opts.on('--test', 'test mode - clears the database!') do
        @@test_mode = true
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
    
    @logger.level = config_value(:log_level, 1)
    @db_log_level = config_value(:log_to_db_level, 2, :db_log_level)
    @log_file = config_value(:log_file, nil)

    @log_file = File.open(@log_file,'w:utf-8') if @log_file
    
    @flush_counter = 0

  end

  def terminate
    @logger.close
    @log_file.close if @log_file
  end

  def flush_log
    @flush_counter += 1
    if @flush_counter > @options[:log_buffer]
      @log_file.flush
      @flush_counter = 0
    end
  end

  def self.write_log(severity, datetime, progname, msg)
    return unless self.instance.log_file
    self.instance.log_file.puts "[#{datetime.to_s}] #{severity} -- #{progname}: #{msg}"
    self.instance.flush_log
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

  def config_value( key, default, key2 = nil )
    result = ConfigFile[key.to_s] || default
    key = key2 if key2
    #noinspection RubyResolve
    result = @options[key.to_sym] if @options[key.to_sym]
    result
  end

end

class Logger
  #noinspection RubyResolve
  attr_accessor :db_log

  def db_logger(severity, datetime, progname, msg)
    # hack required as the logger passes in the message string marked as encoded in US-ASCII, but it really is UTF-8
    msg.encode!('utf-8','utf-8', undef: :replace)
    ::Application.write_log(severity, datetime, progname, msg)
    ::Application.send_log(severity, datetime, progname, msg) if @db_log
    @default_formatter.call(severity, datetime, progname, msg)
  end
end

# to force initialization of the database
@@test_mode = false
@@app = Application.instance
@@app.init
@@logger = @@app.logger
