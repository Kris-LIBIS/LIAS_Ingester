require 'application'

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

  def process_config( cfg )

    Application.log_to(cfg)
    info "Processing config ##{cfg.id}"

    cfg.status = Status::Ingesting

    # run the ingest task
    run_ingest cfg

    # assign pids to ingested objects
    assign_pids cfg

    cfg.status = Status::Ingested if cfg.check_object_status(Status::Ingested)

    if cfg.tasker_log.lines.grep(/COMPLETED - INGEST/).empty?
      error 'Ingest not completed'
      cfg.status = Status::IngestFailed
    end

  rescue => e
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
    cfg.tasker_log.scan(/Ingesting: (\d+).*?\n.*?Pid=(\d+) Success/) do
      pid_list[$1]=$2
    end
# WHY T** F*** does this not work ???
#   cfg.root_objects.all(:status => Status::PreIngested) do |obj|
    cfg.root_objects.each do |obj|
      Application.log_to(obj)
      assign_pid pid_list, obj
      Application.log_end(obj)
    end
  end

  def assign_pid pid_list, obj
    return unless obj.status == Status::PreIngested # needed because the conditional loop doesn't work
    obj.pid = pid_list[obj.vpid]
    obj.status = Status::Ingested if obj.pid
    info "Object id: #{obj.id}, vpid: #{obj.vpid}, pid: #{obj.pid}"
    obj.manifestations.each { |o| assign_pid pid_list, o }
    obj.children.each       { |o| assign_pid pid_list, o }
  end

end
