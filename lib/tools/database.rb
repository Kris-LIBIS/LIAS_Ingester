# coding: utf-8

require 'rubygems'
#require 'sqlite3'
require 'dm-core'
#noinspection RubyResolve
require 'dm-types'
require 'dm-timestamps'
require 'dm-migrations'

require_relative 'config_file'

class Database
  #noinspection RubyResolve
  attr_reader :handle
  attr_reader :logger

  def info(msg)
    @logger << "INFO -- Database: #{msg}" if @logger && @logger.level <= DataMapper::Logger::Levels[:info]
  end

  def error(msg)
    @logger << "INFO -- Database: #{msg}" if @logger && @logger.level <= DataMapper::Logger::Levels[:error]
  end

  def initialize
    new_db = false
    if ConfigFile['db_logging']
      lvl = :warn
      lvl = ConfigFile['db_logging_level'].to_s.downcase.to_sym if ConfigFile['db_logging_level']
      @logger = DataMapper::Logger.new('db_log.txt', lvl, '', true)
#      @logger.set_log(STDOUT, lvl, '', true)
    end
    @db_engine = ConfigFile['db_engine'] || 'SQLITE3'
    @db_engine = @db_engine.to_s.downcase.to_sym
    case @db_engine
      when :sqlite3
        DataMapper.setup(:default, "sqlite3://#{ConfigFile['database']}")
        new_db = true unless File.exist?("#{ConfigFile['database']}")
#      @handle = SQLite3::Database.new("#{ConfigFile['database']}")
        puts "Database set to SQLite3 '#{ConfigFile['database']}'"
      when :oracle
        DataMapper.setup(:default, { :adapter => 'oracle', :user => ConfigFile['db_user'], :password => ConfigFile['db_password'], :host => ConfigFile['db_host'], :port => 1521, :database => ConfigFile['db_database'] })
        puts "Database set to ORACLE"
      when :redis
        DataMapper.setup(:default, { :adapter => 'redis', :host => ConfigFile['db_host'], :port => 6379, :thread_safe => true })
        puts "Database set to REDIS"
      else
        puts $stderr, "Unknown engine type: '#{@db_engine}'"
    end

    DataMapper::Model.raise_on_save_failure = true

    load_models

    if new_db || @@test_mode
      info "Created database #{ConfigFile['database']}"
      new_tables = DataMapper.auto_migrate!
      new_tables.each do |t|
        info "Creating table #{t}"
      end
    else
      info "Reopened database #{ConfigFile['database']}"
      tables = DataMapper.auto_upgrade!
      info 'Upgrading database'
      tables.each do |t|
        info "upgrading table #{t}"
      end
    end

    DataMapper.finalize

  end

  private

  def load_models
#   if @db_engine != :sqlite3 || @handle
    dir = File.dirname(__FILE__) + '/../models'
    dir = File.absolute_path(dir)
    models = Dir.glob("#{dir}/*.rb")
    models.each do |m|
      info "loading model #{m}"
      #noinspection RubyResolve
      require "#{m}"
    end
#    else
#       raise "No database handle found. Cannot load models"
#   end
  end
end
