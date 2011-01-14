class Ingester
  include ApplicationTask
  
  def start
    
    info 'Starting'
    
    cfg_queue = IngestConfig.all(:status => Status::PreIngested)
    
    cfg_queue.each do |cfg|
      
      process_config cfg
      
    end # cfg_queue.each
    
  rescue => e
    handle_exception e
    
  ensure
    info 'Done'
    
  end
  
  def start_config( config_id )
    
    cfg = IngestConfig.first(:id => config_id)
    
    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end
    
    if cfg.status == Status::PreIngested
      # continue
    elsif cfg.status == Status::IngestFailed
      warn "Configuration ##{config_id} failed before and will now be restarted"
      # continue
    elsif cfg.status >= Status::Ingested
      warn "Configuration ##{config_id} allready finished Ingesting."
      return config_id
    end
    
    process_config cfg
    
    return config_id
    
  end
  
  def undo( config_id )
    
    cfg = IngestConfig.first(:id => config_id)
    
    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end
    
    unless Status.phase(cfg.status) == Status.Ingest
      warn "Cannot undo configuration ##{config_id} because status is #{Status.to_string(cfg.status)}."
      return cfg if cfg.status == Status::PreIngested
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
  
  def process_config( cfg )
    
    Application.log_to(cfg)
    info "Processing config ##{cfg.id}"
    
    cfg.status = Status::Ingesting
    cfg.save
    
    # run the ingest task
    run_ingest cfg
    cfg.save
    
    # assign pids to ingested objects
    assign_pids cfg
    
    cfg.status = Status::Ingested
    
    if cfg.tasker_log.lines.grep(/COMPLETED - INGEST/).empty?
      error 'Ingest not completed'
      cfg.status = Status::IngestFailed
    end
    
    warn 'Some objects failed during Ingest' unless cfg.check_object_status(Status::Ingested)
    
  rescue => e
    cfg.status = Status::IngestFailed
    handle_exception e
    
  ensure
    cfg.save
    Application.log_end(cfg)
    
  end # process_config
  
  def run_ingest cfg
    # run ingest task
    Dir.chdir("#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_bin_dir']}") do
      info "Running ./tasker_fg.sh #{ConfigFile['user']} staff creator:staff #{cfg.ingest_id}"
      cfg.tasker_log = %x(./tasker_fg.sh #{ConfigFile['user']} staff creator:staff #{cfg.ingest_id})
    end
  end
  
  def assign_pids cfg
    return if cfg.tasker_log.nil?
    pid_list = Hash.new
    cfg.tasker_log.scan(/Ingesting: (\d+).*?\n?.*?Pid=(\d+) Success/) do
      pid_list[$1]=$2
    end
# WHY T** F*** does this not work ???
#   cfg.root_objects.all(:status => Status::PreIngested) do |obj|
    cfg.root_objects.each do |obj|
      next unless obj.status == Status::PreIngested # needed because the conditional loop doesn't work
      Application.log_to(obj)
      assign_pid pid_list, obj
      obj.save
      Application.log_end(obj)
    end
  end
  
  def assign_pid pid_list, obj
    obj.pid = pid_list[obj.vpid]
    obj.status = Status::IngestFailed
    obj.status = Status::Ingested if obj.pid
    info "Object id: #{obj.id}, vpid: #{obj.vpid}, pid: #{obj.pid}"
    obj.manifestations.each { |o| assign_pid pid_list, o }
    obj.children.each       { |o| assign_pid pid_list, o }
  end
  
end
