#!/usr/bin/env ruby

begin
#gem install sqlite3-ruby -- --with-sqlite3-dir=/exlibris/product/sqlite-3.6.15
#gem install do_sqlite3 -- --with-sqlite3-dir=/exlibris/product/sqlite-3.6.15
#sudo gem install sqlite3-ruby
#sudo gem install do_sqlite3 dm-core dm-types dm-timestamps

$LOAD_PATH << './lib'
require 'rubygems'
require 'thread'
require 'logger'
require 'agents/pre_processor'
require 'agents/run_handler'
require 'agents/pre_ingester'
require 'agents/ingester'
require 'tools/database'

@@emergency_timeout = 5

@@app_state = true

def terminate( signal )
  puts "#{signal} : Terminating ..."
  @@app_state = false
end

Signal.trap('TERM') {terminate('TERM')}
Signal.trap('QUIT') {terminate('QUIT')}
Signal.trap('INT') {terminate('INT')}

@@logger = Logger.new(STDOUT)
@@logger.datetime_format = "%Y-%m-%d %H:%M:%S"

database = Database.new
run_queue = SizedQueue.new(5)
cfg_queue = SizedQueue.new(20)
ingest_queue = SizedQueue.new(20)

SLEEP_TIME = 1
@@ingester = IngestAgent.new(ingest_queue)
@@pre_ingester = PreIngestAgent.new(cfg_queue, ingest_queue)
@@pre_processor = PreProcessorAgent.new(run_queue, cfg_queue)
@@run_handler = RunHandlerAgent.new(run_queue)

Signal.trap('USR1') {
  @@run_handler.force_rescan
  @@pre_processor.force_rescan
  @@pre_ingester.force_rescan
  @@ingester.force_rescan
}

@@run_handler.thread.join if @@run_handler.thread.alive?
@@pre_processor.thread.join if @@pre_processor.thread.alive?
@@pre_ingester.thread.join if @@pre_ingester.thread.alive?
@@ingester.thread.join if @@ingester.thread.alive?

rescue Exception => e
  puts e
  puts e.backtrace
end

puts "DONE"
@@logger.close


