#!/usr/bin/env ruby

require 'rubygems'
require_relative 'lib/application'

# Makes our life much easier
def nil.each #(&block)
end

if @@app.options[:action]
  
  if ARGV.size < 1
    Application.error 'A config file/number argument is required when you want to start the ingester'
    exit
  end

  initializer = Initializer.new
  pre_processor = PreProcessor.new
  pre_ingester = PreIngester.new
  ingester = Ingester.new
  post_ingester = PostIngester.new

  result = 0

  ARGV.each do |arg|

    configs = nil

    case @@app.options[:start]

    when 1

      run_id = initializer.send(@@app.options[:action], arg)
      next if run_id.class == IngestRun

      configs = pre_processor.start run_id  unless @@app.options[:end] and @@app.options[:end] < 2
      configs.each do |cfg_id|
        cfg_id = pre_ingester.start cfg_id  unless @@app.options[:end] and @@app.options[:end] < 3
        cfg_id = ingester.start cfg_id      unless @@app.options[:end] and @@app.options[:end] < 4
        cfg_id = post_ingester.start cfg_id unless @@app.options[:end] and @@app.options[:end] < 5

        result = cfg_id
      end

    when 2

      configs = pre_processor.send(@@app.options[:action], arg)
      next if configs.class == IngestRun

      configs.each do |cfg_id|
        cfg_id = pre_ingester.start cfg_id  unless @@app.options[:end] and @@app.options[:end] < 3
        cfg_id = ingester.start cfg_id      unless @@app.options[:end] and @@app.options[:end] < 4
        cfg_id = post_ingester.start cfg_id unless @@app.options[:end] and @@app.options[:end] < 5

        result = cfg_id
      end

    when 3

      cfg_id = pre_ingester.send(@@app.options[:action], arg)
      next if cfg_id.class == IngestConfig

      cfg_id = ingester.start cfg_id        unless @@app.options[:end] and @@app.options[:end] < 4
      cfg_id = post_ingester.start cfg_id   unless @@app.options[:end] and @@app.options[:end] < 5

      result = cfg_id

    when 4

      cfg_id = ingester.send(@@app.options[:action], arg)
      next if cfg_id.class == IngestConfig

      cfg_id = post_ingester.start cfg_id   unless @@app.options[:end] and @@app.options[:end] < 5

      result = cfg_id

    when 5

      cfg_id = post_ingester.send(@@app.options[:action], arg)

      result = cfg_id

    end

  end
  
  @@app.terminate
  exit result

end
