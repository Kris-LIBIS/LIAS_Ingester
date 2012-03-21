# coding: utf-8

#require 'application'
require 'tools/exceptions'

# Makes our life much easier
def nil.each #(&block)
end

$application_dir = File.expand_path "#{File.dirname(__FILE__)}/.."

module IngesterTask

  def IngesterTask.included(klass)
    klass.class_eval {

      def self.debug(msg, trace = false)
        Application.debug self.name, &lambda{msg}
        Thread.current.backtrace.each { |x| Application.debug self.name, &lambda{x} } if trace
      end

      def self.info(msg, trace = false)
        Application.info self.name, &lambda{msg}
        Thread.current.backtrace.each { |x| Application.info self.name, &lambda{x} } if trace
      end

      def self.warn(msg, trace = false)
        Application.warn self.name, &lambda{msg}
        Thread.current.backtrace.each { |x| Application.warn self.name, &lambda{x} } if trace
      end

      def self.error(msg, trace = true)
        Application.error self.name, &lambda{msg}
        Thread.current.backtrace.each { |x| Application.error self.name, &lambda{x} } if trace
      end

      def self.fatal(msg, trace = true)
        Application.fatal self.name, &lambda{msg}
        Thread.current.backtrace.each { |x| Application.fatal self.name, &lambda{x} } if trace
      end

    }
  end

  def debug(msg, trace = false)
    Application.debug self.class, &lambda{msg}
    Thread.current.backtrace.each { |x| Application.debug self.class, &lambda{x} } if trace
  end

  def info(msg, trace = false)
    Application.info self.class, &lambda{msg}
    Thread.current.backtrace.each { |x| Application.info self.class, &lambda{x} } if trace
  end

  def warn(msg, trace = false)
    Application.warn self.class, &lambda{msg}
    Thread.current.backtrace.each { |x| Application.warn self.class, &lambda{x} } if trace
  end

  def error(msg, trace = true)
    Application.error self.class, &lambda{msg}
    Thread.current.backtrace.each { |x| Application.error self.class, &lambda{x} } if trace
  end

  def fatal(msg, trace = true)
    Application.fatal self.class, &lambda{msg}
    Thread.current.backtrace.each { |x| Application.fatal self.class, &lambda{x} } if trace
  end

  def handle_exception(e)
    print_exception e
    raise AbortException.new
  end

  def print_exception(e)
    unless e.instance_of?(AbortException)
      error "Exception in #{self.class}: #{e.message}", false
      e.backtrace.each { |x| error "#{x}", false }
    end
  end
  
end
