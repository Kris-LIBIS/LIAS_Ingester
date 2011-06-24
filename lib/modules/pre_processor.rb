require 'ingester_module'
require 'tools/complex_file_collecter'

require_relative 'file_checker'

class PreProcessor
  include IngesterModule
  
  public
  
  def start_queue
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
  
  def start( run_id )
    
    begin
      error "Run ##{run_id} not found"
      return []
    end unless run = IngestRun.first(:id => run_id)
    
    begin

      ApplicationStatus.instance.run = run

      case run.status
      when Status::Idle ... Status::Initialized
        error "Cannot yet PreProcess run ##{run_id}. Status is '#{Status.to_string(run.status)}'"
      when Status::Initialized ... Status::PreProcessing
        # continue
        process_run run
      when Status::PreProcessing ... Status::PreProcessed
        warn "Restarting PreProcess of run #{run_id} with status '#{Status.to_string(run.status)}'"
        restart run_id
      when Status::PreProcessed .. Status::Finished
        warn "Skipping preprocessing of run ##{run_id} because status is '#{Status.to_string(run.status)}'"
      end
      
    ensure
      ApplicationStatus.instance.run = nil
      
    end
    
    collect_configs run
    
  end
  
  def undo( run_id )
    
    begin
      error "Run ##{run_id} not found"
      return nil
    end unless run = IngestRun.first(:id => run_id)
    
    unless Status.phase(run.status) == Status::PreProcess
      warn "Cannot undo run ##{run_id} because status is #{Status.to_string(run.status)}."
      return run if run.status == Status::Initialized
      return nil
    end
    
    undo_run run
    
    run
    
  end
  
  def restart( run_id )
    
    if run = undo(run_id)
      info "Restarting run ##{run_id}"
      process_run run
      return collect_configs(run)
    end
    
    nil
    
  end
  
  def continue( run_id )
    
    begin
      error "Run ##{run_id} not found"
      return []
    end unless run = IngestRun.first(:id => run_id)
    
    process_run( run )
    collect_configs run
    
  end
  
  private
  
  def collect_configs( run )
    run.ingest_configs.collect { |cfg| cfg.status >= Status::PreProcessed ? cfg.id : nil }.compact
  end
  
  def process_run( run )
    
    start_time = Time.now
    ApplicationStatus.instance.run = run

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
    print_exception e
    
  ensure
    run.save
    info "Run ##{run.id} processed. Elapsed time: #{elapsed_time(start_time)}."
    ApplicationStatus.instance.run = nil

  end
  
  private
  
  def process_config( config )
    
    ApplicationStatus.instance.cfg = config
    config.status = Status::PreProcessing
    config.save
    
    @checker = FileChecker.new config
    @collecter = nil
    @collecter = ComplexFileCollecter.new(config) if config.complex or config.mets
    
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
      # Note: do not attempt to remove them from the run set in process_object
      # as Ruby does not allow to change a set while iterating over it
      config.ingest_run.ingest_objects -= config.ingest_objects
      config.status = Status::PreProcessed if config.check_object_status(Status::PreProcessed)
      info "Placed config ##{config.id} on the queue."
    end
    
  rescue Exception => e
    config.status = Status::PreProcessFailed
    handle_exception e
    
  ensure
    ApplicationStatus.instance.cfg = nil
    config.save
    
  end
  
  def process_object( object, config )
    
    ApplicationStatus.instance.obj = object

    if object.status == Status::PreProcessed
      info "Skipping object ##{object.id}."
      Application.log_end object
      return
    end
    
    info "Processing object ##{object.id}: '#{object.file_path}'"
    object.status = Status::PreProcessing
    object.save
    
    if not @checker.match object
      debug "Object ##{object.id} did not match: #{object.message}"
      object.status = Status::Initialized
      object.message = nil
    elsif not @checker.check object
      error "Object ##{object.id} failed tests: '#{object.message}'"
      object.status = Status::PreProcessFailed
    else
      debug "Object ##{object.id} passed tests"
      config.add_object object
      info "Object ##{object.id} added"
      object.status = Status::PreProcessed
      debug "Object ##{object.id} updated status"
      unless @collecter.nil? or @collecter.check object
        error "Object ##{object.id} failed building complex object"
        object.status = Status::PreProcessFailed
      end
      
    end
    
  rescue Exception => e
    object.status = Status::PreProcessFailed
    handle_exception e
    
  ensure
    object.save
    info "Object ##{object.id} preprocessed"
    ApplicationStatus.instance.obj = nil

  end
  
  def undo_run( run )
    
    info "Undo run ##{run.id} PreProcess."
    ApplicationStatus.instance.run = run
    
    run.ingest_configs.each do |cfg|
      undo_config cfg
    end
    
    run.status = Status::Initialized
    run.save
    
    info "Run ##{run.id} PreProcess undone."
    ApplicationStatus.instance.run = nil

  end
  
  def undo_config( cfg )
    
    start_time = Time.now
    info "Undo configuration ##{cfg.id} PreProcess."
    ApplicationStatus.instance.cfg = cfg

    cfg.ingest_objects.each do |obj|
      undo_object obj
    end
    
    cfg.status = Status::New
    cfg.save
    
    info "Configuration ##{cfg.id} PreProcess undone. Elapsed time: #{elapsed_time start_time}."
    ApplicationStatus.instance.cfg = nil
    
  end
  
  def undo_object( obj )
    
    info "Undo object ##{obj.id} PreProcess."
    ApplicationStatus.instance.obj = obj
    
    obj.children.each { |child| undo_object child }
    
    unless obj.usage_type == 'ORIGINAL'
      debug "Deleting object ##{obj.id} from database"
      obj.destroy
      return
    end
    
    debug "Returning object ##{obj.id} to run."
    obj.get_run.add_object obj
    obj.get_config.del_object obj
    obj.status = Status::Initialized
    
    info "Object ##{obj.id} PreProcess undone."
    ApplicationStatus.instance.obj = nil
    
  end

end
