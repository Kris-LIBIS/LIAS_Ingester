$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.dirname(__FILE__) + '/lib'

require 'rubygems'
require 'singleton'
require 'logger'
require 'optparse'

module ApplicationTask

  def debug(msg)
    Application.debug self.class, &lambda{msg}
  end

  def info(msg)
    Application.info self.class, &lambda{msg}
  end

  def warn(msg)
    Application.warn self.class, &lambda{msg}
  end

  def error(msg)
    Application.error self.class, &lambda{msg}
  end

  def fatal(msg)
    Application.fatal self.class, &lambda{msg}
  end

  def handle_exception(e)
    unless e.instance_of?(AbortException)
      error "Exception in #{self.class}: #{e.message}"
      e.backtrace.each { |x| error "#{x}" }
    end
    raise AbortException.new
  end

  def print_exception(e)
    unless e.instance_of?(AbortException)
      error "Exception in #{self.class}: #{e.message}"
      e.backtrace.each { |x| error "#{x}" }
    end
  end

end
require 'tools/database'
require 'models/common/status'
require 'modules/initializer'
require 'modules/pre_processor'
require 'modules/pre_ingester'
require 'modules/ingester'
require 'modules/post_ingester'

class Application
  include Singleton

  attr_reader :logger
  attr_reader :db_log_level
  attr_accessor :log_objects

  def self.dir
    File.dirname(__FILE__)
  end

  def self.log_to(obj)
    return if obj.nil?
    self.instance.log_objects << obj
  end

  def self.log_end(obj)
    obj.save unless obj.nil?
    return false if self.instance.log_objects.empty?
    return (obj == self.instance.log_objects.pop) if (obj == nil or self.instance.log_objects[-1] == obj)
    false
  end

  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    @database = Database.new
    @log_objects = Array.new
    @logger.formatter = proc { |severity, datetime, progname, msg|
      @logger.db_logger(severity, datetime, progname, msg)
    }
    @logger.level = ConfigFile['log_level'] || 1
    @db_log_level = ConfigFile['log_to_db_level'] || 2
  end

  def terminate
    @logger.close
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

# to force initialization of the database
@@app = Application.instance

class Logger
  attr_accessor :db_log

  def db_logger(severity, datetime, progname, msg)
    ::Application.send_log(severity,datetime,progname,msg) if @db_log
    @default_formatter.call(severity, datetime, progname, msg)
  end
end

class AbortException < StandardError
end

