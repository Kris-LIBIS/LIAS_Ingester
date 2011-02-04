require 'lib/tools/exceptions'
require 'lib/application'
require 'chronic_duration'

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
  
  def elapsed_time(start_time)
    ChronicDuration.output((Time.now - start_time).round(3), :format => :long)
  end

  def continue(id)
    
    error "Cannot continue the ingest at this stage. Please used 'undo' + 'start' or 'restart' this stage instead."
    
    nil
    
  end
  
end
