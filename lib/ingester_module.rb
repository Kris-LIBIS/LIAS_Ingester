# coding: utf-8

require 'chronic_duration'
require_relative 'ingester_task'

module IngesterModule
  include IngesterTask

  def elapsed_time(start_time)
    ChronicDuration.output((Time.now - start_time).round(3), :format => :long)
  end

  def continue(id)
    
    error "Cannot continue the ingest at this stage. Please used 'undo' + 'start' or 'restart' this stage instead."
    
    nil
    
  end
  
end

require_relative 'application_status'
