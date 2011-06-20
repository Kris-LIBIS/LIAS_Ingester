#require 'application'
require 'tools/exceptions'

# Makes our life much easier
def nil.each #(&block)
end

$ApplicationDir = File.expand_path "#{File.dirname(__FILE__)}/.."

module IngesterTask

  def IngesterTask.included(klass)
    klass.class_eval {

      def self.debug(msg)
        Application.debug self.name, &lambda{msg}
      end

      def self.info(msg)
        Application.info self.name, &lambda{msg}
      end

      def self.warn(msg)
        Application.warn self.name, &lambda{msg}
      end

      def self.error(msg)
        Application.error self.name, &lambda{msg}
      end

      def self.fatal(msg)
        Application.fatal self.name, &lambda{msg}
      end

    }
  end

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
