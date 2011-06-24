require "singleton"
require_relative 'application'

class ApplicationStatus
  include Singleton

  attr_reader :run, :cfg, :obj

  def run=(run)
    run.nil? ? Application.log_end(@run) : Application.log_to(run)
    @run = run
  end

  def cfg=(cfg)
    cfg.nil? ? Application.log_end(@cfg) : Application.log_to(cfg)
    @cfg = cfg
  end

  def obj=(obj)
    obj.nil? ? Application.log_end(@obj) : Application.log_to(obj)
    @obj = obj
  end

end