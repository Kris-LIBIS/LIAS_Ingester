require 'rubygems'
require 'sqlite3'
require 'dm-core'
require 'dm-types'
require 'dm-timestamps'
require 'dm-migrations'
require 'tools/config_file'

class Database
  attr_reader :handle
  attr_reader :logger

  def info(msg)
    @logger << "INFO -- Database: #{msg}" if @logger && @logger.level <= DataMapper::Logger::Levels[:info]
  end
  
  def initialize
    new_db = false
    if ConfigFile['db_logging']
      lvl = :warn
      lvl = ConfigFile['db_logging_level'].to_s.downcase.to_sym if ConfigFile['db_logging_level']
      @logger = DataMapper::Logger.new STDOUT
      @logger.set_log(STDOUT, lvl, '', true)
    end
    DataMapper.setup(:default, "sqlite3://#{ConfigFile['database']}")
    new_db = true unless File.exist?("#{ConfigFile['database']}")
#    DataMapper.setup(:default, {:adapter => 'oracle', :user => 'ingester', :password => 'ingester', :host => 'aleph08', :port => 1521, :database => '/dtl3'} )
    DataMapper.setup(:default, 'oracle://ingester:ingester@localhost:1521/?sid=dtl3')
    
    @handle = SQLite3::Database.new("#{ConfigFile['database']}")

    DataMapper::Model.raise_on_save_failure = true
    
    load_models
    
    if new_db
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
    if @handle
      dir = File.dirname(__FILE__) + '/../models'
      dir = File.absolute_path(dir)
      models = Dir.glob("#{dir}/*.rb")
      models.each do |m|
        info "loading model #{m}"
        require "#{m}"
      end
    else
      raise "No database handle found. Cannot load models"
    end
  end
end
