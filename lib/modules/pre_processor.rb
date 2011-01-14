require File.dirname(__FILE__) + '/file_checker'
require 'lib/tools/complex_file_collecter'

class PreProcessor
  include ApplicationTask
  
  public
  
  def start
    info 'Starting'
    
      run_queue = IngestRun.all(:status => Status::Initialized)
      
      run_queue.each do |run|
        process_run run
      end # run_queue.each
      
    rescue Exception => e
      handle_exception e
      
    ensure
      info 'Done'
      
  end
  
  def start_run( run_id )
    
    result = []
    
    if run = IngestRun.first(:id => run_id)
      
      if run.status == Status::Initialized
        process_run run
        run.ingest_configs.each do |cfg|
          result << cfg.id if cfg.status == Status::PreProcessed
        end 
      else
        error "Failed to start run ##{run_id} because status is '#{Status.to_string(run.status)}'"
      end
      
    end
    
    result
    
  end
  
  def undo( run_id )
    
    cfg = IngestConfig.first(:id => config_id)
    
    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end
    
    unless Status.phase(cfg.status) == Status.PreProcess
      warn "Cannot undo configuration ##{config_id} because status is #{Status.to_string(cfg.status)}."
      return cfg if cfg.status == Status::New
      return nil
    end
    
    ##### TODO
    error '\'undo\' not yet implemented'
    return nil
    
    # cfg
    
  end
  
  def restart_config( config_id )
    
    if cfg = undo(config_id)
      info "Restarting config ##{config_id}"
      process_config cfg, true
      return config_id
    end
    
    nil
    
  end
  
  def continue( config_id )
    error '\'continue\' not yet implemented'
  end
  
  private
  
  def process_run( run )
    
    Application.log_to(run)
    
    info "Processing run ##{run.id}"
    run.status = Status::PreProcessing
    run.save
    
    # for each configuration
    run.ingest_configs.each do |config|
      process_config config
    end # ingest_configs.each
    unless run.ingest_objects.empty?
      warn "#{run.ingest_objects.size} Objects remain unprocessed in run ##{run.id}"
    end
    run.status = Status::PreProcessed
    
  rescue Exception => e
    run.status = Status::PreProcessFailed
    handle_exception e
    
  ensure
    run.save
    Application.log_end(run)
    
  end
  
  private
  
  def process_config( config )
    
    Application.log_to(config)
    config.status = Status::PreProcessing
    config.save
    
    @checker = FileChecker.new config
    @collecter = nil
    @collecter = ComplexFileCollecter.new(config) if config.complex
    
    info "Processing config ##{config.id}"
    collected_objects = config.ingest_run.ingest_objects
    collected_objects.each do |object|
      process_object object, config
    end
    config.save
    if config.get_objects.empty?
      config.status = Status::Idle
      warn "Config ##{config.id} did not match any objects"
    else
      # all files that matched the config criteria are now part of the config
      # these files should be removed from the run
      config.ingest_run.ingest_objects -= config.ingest_objects
      config.status = Status::PreProcessed if config.check_object_status(Status::PreProcessed)
      info "Placed config ##{config.id} on the queue."
    end
    
  rescue Exception => e
    config.status = Status::PreProcessFailed
    handle_exception e
    
  ensure
    Application.log_end(config)
    config.save
    
  end
  
  def process_object( object, config )
    
    Application.log_to(object)
    
    info "Processing object ##{object.id}: '#{object.file_path}'"
    object.status = Status::PreProcessing
    object.save
    
    if not(@checker.match(object))
      object.status = Status::New
      object.message = nil
      debug "Object ##{object.id} did not match"
    elsif not(@checker.check(object))
      error "Object ##{object.id} failed tests: '#{object.message}'"
      object.status = Status::PreProcessFailed
    else
      debug "Object ##{object.id} passed tests"
      config.add_object(object)
      debug "Object ##{object.id} added"
      object.status = Status::PreProcessed
      debug "Object ##{object.id} updated status"
      unless @collecter.nil? or @collecter.check(object)
        error "Object ##{object.id} failed building complex object"
        object.status = Status::PreProcessFailed
      end
      
    end
    
  rescue Exception => e
    object.status = Status::PreProcessFailed
    handle_exception e
    
  ensure
    info "Object ##{object.id} preprocessed"
    Application.log_end(object)
    
  end
  
end
