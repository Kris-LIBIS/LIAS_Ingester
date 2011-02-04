require 'lib/application_task'
require 'lib/webservices/digital_entity_manager'

class Ingester
  include ApplicationTask
  
  def start_queue
    
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
  
  def start( config_id )
    
    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless cfg = IngestConfig.first(:id => config_id)
    
    begin
      
      Application.log_to cfg.ingest_run
      Application.log_to cfg
      
      case cfg.status
      when Status::Idle ... Status::PreIngested
        # Oops! Not yet ready.
        error "Cannot yet Ingest configuration ##{config_id}. Status is '#{Status.to_string(cfg.status)}'."
      when Status::PreIngested ... Status::Ingesting
        # Excellent! Continue ...
        process_config cfg
      when Status::Ingesting ... Status::Ingested
        warn "Restarting Ingest of configuration #{config_id} with status '#{Status.to_string(cfg.status)}'."
        restart_config config_id
      when Status::Ingested .. Status::Finished
        warn "Skipping Ingest of configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
      end
      
    ensure
      Application.log_end cfg
      Application.log_end cfg.ingest_run
      
    end
    
    config_id
    
  end
  
  def undo( config_id )
    
    cfg = IngestConfig.first(:id => config_id)
    
    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end
    
    unless Status.phase(cfg.status) == Status::Ingest
      warn "Cannot undo configuration ##{config_id} because status is #{Status.to_string(cfg.status)}."
      return cfg if cfg.status == Status::PreIngested
      return nil
    end
    
    undo_config cfg
    
    cfg
    
  end
  
  def restart( config_id )
    
    if cfg = undo(config_id)
      info "Restarting config ##{config_id}"
      process_config cfg
      return config_id
    end
    
    nil
    
  end
  
  private
  
  def process_config( cfg )
    
    start_time = Time.now
    Application.log_to cfg.ingest_run
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
    info "Config ##{cfg.id} processed. Elapsed time: #{elapsed_time(start_time)}."
    Application.log_end(cfg)
    Application.log_end cfg.ingest_run
    
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
  
  def undo_config( cfg )
    start_time = Time.now
    info "Undo configuration ##{cfg.id} Ingest."
    cfg.root_objects.each do |obj|
      undo_object obj
    end
    cfg.tasker_log = nil
    cfg.status = Status::PreIngested
    cfg.save
    info "Configuration ##{cfg.id} Ingest undone. Elapsed time: #{elapsed_time(start_time)}."
  end
  
  def undo_object( obj )
    info "Undo object ##{obj.id} Ingest."
    obj.status = Status::Ingesting
    obj.manifestations.each { |o| undo_object o }
    obj.children.each       { |o| undo_object o }
    delete_object obj
    obj.status = Status::PreIngested if obj.status == Status::Ingesting
    obj.save
    info "Object ##{obj.id} Ingest undone."
  end
  
  def delete_object( obj )
    return unless obj.pid
    result = DigitalEntityManager.instance.delete_object obj.pid
    unless result[:error].empty?
      result[:error].each { |e| error "Error calling web service: #{e}" }
      error "Failed to delete object #{obj.pid}"
      obj.status = Status::IngestFailed
    else
      info "Deleted object #{obj.pid}"
      obj.pid = nil
    end
  end
  
end
