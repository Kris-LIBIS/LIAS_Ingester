#!/usr/bin/env ruby

# coding: utf-8

require_relative 'lib/application'

require 'modules/sharepoint_collector'
require 'modules/sharepoint_post_processor'

if @@app.options[:action]
  
  if ARGV.size < 1
    Application.error 'A config file/number argument is required when you want to start the ingester'
    exit
  end

  collector = SharepointCollector.new
  collector.data_dir = @@app.config_value :sharepoint_datadir, './streams'

  pre_processor = PreProcessor.new
  pre_ingester = PreIngester.new
  ingester = Ingester.new
  post_ingester = PostIngester.new
  post_processor = SharepointPostProcessor.new collector.metadata_file, 'metadata.sql', collector.mapping_file

  ARGV.each do |arg|

    configs = []

    case @@app.options[:module_id]

      when 1

      run_id = collector.send(@@app.options[:action], arg)
      next unless run_id

      configs = pre_processor.start run_id  unless @@app.options[:end] and @@app.options[:end] < 2
      configs.each do |cfg_id|
        cfg_id = pre_ingester.start cfg_id  unless @@app.options[:end] and @@app.options[:end] < 3
        next unless cfg_id
        cfg_id = ingester.start cfg_id      unless @@app.options[:end] and @@app.options[:end] < 4
        next unless cfg_id
        cfg_id = post_ingester.start cfg_id unless @@app.options[:end] and @@app.options[:end] < 5
        next unless cfg_id
        #noinspection RubyUnusedLocalVariable
        cfg_id = post_processor.start cfg_id unless @@app.options[:end] and @@app.options[:end] < 6
      end

    when 2

      configs = pre_processor.send(@@app.options[:action], arg)
      next unless configs.class == Array

      configs.each do |cfg_id|
        cfg_id = pre_ingester.start cfg_id  unless @@app.options[:end] and @@app.options[:end] < 3
        next unless cfg_id
        cfg_id = ingester.start cfg_id      unless @@app.options[:end] and @@app.options[:end] < 4
        next unless cfg_id
        cfg_id = post_ingester.start cfg_id unless @@app.options[:end] and @@app.options[:end] < 5
        next unless cfg_id
        #noinspection RubyUnusedLocalVariable
        cfg_id = post_processor.start cfg_id unless @@app.options[:end] and @@app.options[:end] < 6
      end

    when 3

      cfg_id = pre_ingester.send(@@app.options[:action], arg)
      next unless cfg_id

      cfg_id = ingester.start cfg_id        unless @@app.options[:end] and @@app.options[:end] < 4
      next unless cfg_id
      cfg_id = post_ingester.start cfg_id   unless @@app.options[:end] and @@app.options[:end] < 5
      next unless cfg_id
      #noinspection RubyUnusedLocalVariable
      cfg_id = post_processor.start cfg_id   unless @@app.options[:end] and @@app.options[:end] < 6

    when 4

      cfg_id = ingester.send(@@app.options[:action], arg)
      next unless cfg_id

      cfg_id = post_ingester.start cfg_id   unless @@app.options[:end] and @@app.options[:end] < 5
      next unless cfg_id
      #noinspection RubyUnusedLocalVariable
      cfg_id = post_processor.start cfg_id   unless @@app.options[:end] and @@app.options[:end] < 6

    when 5

      cfg_id = post_ingester.send(@@app.options[:action], arg)
      next unless cfg_id
      #noinspection RubyUnusedLocalVariable
      cfg_id = post_processor.start cfg_id   unless @@app.options[:end] and @@app.options[:end] < 6

    when 6

      cfg_id = post_processor.send(@@app.options[:action], arg)

    end

  end
  
  @@app.terminate
  exit

end
