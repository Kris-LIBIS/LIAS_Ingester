require 'lib/application_task'
require 'lib/webservices/digital_entity_manager'
require 'lib/tools/xml_reader'
require 'awesome_print'

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

  def continue( config_id )
    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless cfg = IngestConfig.first(:id => config_id)
    
    begin

      Application.log_to cfg.ingest_run
      Application.log_to cfg

      case cfg.status
      when Status::Idle ... Status::Ingesting
        # Oops! Not yet ready.
        error "Cannot continue Ingest configuration ##{config_id}. Status is '#{Status.to_string(cfg.status)}'."
      when Status::Ingesting
        error "Cannot continue Ingest configuration ##{config_id}. Status is '#{Status.to_string(cfg.status)}'."
      when Status::IngestFailed ... Status::PostIngesting
        # Excellent! Continue ...
        warn "Continuing just after Ingest configuration #{config_id} with status '#{Status.to_string(cfg.status)}'."
        process_config cfg, true
      when Status::PostIngesting .. Status::Finished
        warn "Skipping Ingest of configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
      end

    ensure
      Application.log_end cfg
      Application.log_end cfg.ingest_run

    end

    config_id

  end

  private

  def process_config( cfg, continue = false )

    start_time = Time.now
    Application.log_to cfg.ingest_run
    Application.log_to(cfg)
    info "Processing config ##{cfg.id}"

    cfg.status = Status::Ingesting
    cfg.save

    unless continue
      # run the ingest task
      run_ingest cfg
      cfg.save
    end

    cfg.status = Status::Ingested

    # assign pids to ingested objects
    assign_pids cfg

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
  
  def fix_pidlist( pid_list, cfg )
  	fixed_pid_list = {}
  	pid_list.each do |xmlnr, pid|
  	  file_name = cfg.ingest_dir + "/ingest/digital_entities/#{xmlnr}.xml"
  	  doc = XmlReader::parse_file file_name
  	  vpid_node = filesec.xpath('//xb:digital_entity/vpid').first
  	  error "Cannot detect assigned PID: failed to find <vpid> entry in #{file_name}." unless vpid_node
	    fixed_pid_list[vpid_node.content] = pid if vpid_node
	  end
	  return fixed_pid_list
  end
  
  def fix_pidlist_for_mets( pid_list, cfg )
    doc = XmlReader::parse_file cfg.ingest_dir + '/ingest/digital_entities/0.xml'
    filesec = XmlReader::parse_string doc.xpath('//md/value[../type="fileSec"]').first.content.to_s
    fixed_pid_list = {}
    filesec.xpath('//mets:file').each do |f|
      vpid = f['ID'].gsub('file_','')
      mets_id = f.xpath('mets:FLocat').first['href'].gsub('METSID-','')
      fixed_pid_list[vpid] = pid_list[mets_id]
    end
    fixed_pid_list[cfg.root_objects.first.vpid] = pid_list['0']
    return fixed_pid_list
  end
  
  def get_pidlist( cfg )
    pid_list = {}
    if cfg.tasker_log
      cfg.tasker_log.scan(/Ingesting: (\d+).*?\n?.*?Pid=(\d+) Success/) do
        pid_list[$1]=$2
      end
      pid_list = fix_pidlist pid_list, cfg
      if cfg.mets
        pid_list = fix_pidlist_for_mets pid_list, cfg
      end
    end
    return pid_list

  end

  def assign_pids cfg
    pid_list = get_pidlist cfg
    # WHY T** F*** does this not work ???
    # cfg.root_objects.all(:status => Status::PreIngested) do |obj|
    cfg.root_objects.each do |obj|
      next unless obj.status >= Status::PreIngested && obj.status < Status::PostIngesting  
      Application.log_to(obj)
      assign_pid pid_list, obj
      obj.save
      Application.log_end(obj)
    end
  end

  def assign_pid pid_list, obj
    obj.pid = pid_list[obj.vpid]
    obj.status = Status::IngestFailed
    obj.status = Status::Ingested if obj.pid || obj.branch?
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
