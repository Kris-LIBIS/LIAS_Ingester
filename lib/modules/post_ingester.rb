require 'lib/application_task'
require 'lib/webservices/digital_entity_manager'
require 'lib/webservices/meta_data_manager'

class PostIngester
  include ApplicationTask
  
  def start_queue
    
    info 'Starting'
    
    cfg_queue = IngestConfig.all(:status => Status::Ingested)
    
    cfg_queue.each do |cfg|
      
      process_config cfg
      
    end # cfg_queue.each
    
  rescue => e
    handle_exception e
    
  ensure
    info 'Done'
    
  end # start
  
  def start( config_id )
    
    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless cfg = IngestConfig.first(:id => config_id)
    
    begin
      
      Application.log_to cfg.ingest_run
      Application.log_to cfg
      
      case cfg.status
      when Status::Idle ... Status::Ingested
        # Oops! Not yet ready.
        error "Cannot yet PreIngest configuration ##{config_id}. Status is '#{Status.to_string(cfg.status)}'."
      when Status::Ingested ... Status::PostIngesting
        # Excellent! Continue ...
        process_config cfg
      when Status::PostIngesting ... Status::PostIngested
        info "PostIngest of configuration ##{config_id} failed the last time. The current status is unreliable, so we restart."
        process_config cfg
      when Status::PostIngested ... Status::Finished
        if cfg.root_objects.all? { |obj| obj.status >= Status::PostIngested }
          warn "Skipping PostIngest of configuration ##{config_id} because all objects are PostIngested."
        else
          info "Continuing PostIngest of configuration #{config_id}. Some objects are not yet PostIngested."
          continue cfg
        end
      when Status::Finished
        warn "Skipping PreIngest of configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
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
    
    unless Status.phase(cfg.status) == Status::PostIngest
      warn "Cannot undo configuration ##{config_id} because status is #{Status.to_string(cfg.status)}."
      return cfg if cfg.status == Status::Ingested
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
    
    cfg = IngestConfig.first(:id => config_id)
    
    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end
    
    process_config cfg
    
    config_id
    
  end
  
  private
  
  def process_config(cfg)
    
    start_time = Time.now
    Application.log_to cfg.ingest_run
    Application.log_to(cfg)
    info "Processing config ##{cfg.id}"
    
    cfg.status = Status::PostIngesting
    cfg.save
    
    failed_objects = []
    
# For some strange reason the statement below does not work
#      cfg.ingest_objects.all(:status => Status::Ingested) do |obj|
# But this does work !?!?:
    cfg.root_objects.each do |obj|
      
      next unless obj.status == Status::Ingested
      
      process_object obj
      
      failed_objects << obj unless obj.status == Status::PostIngested
      
    end # ingest_objects.all
    
    cfg.status = Status::PostIngested
    
  rescue => e
    cfg.status = Status::PostIngestFailed
    handle_exception e
    
  ensure
    cfg.save
    warn "#{failed_objects.size} objects failed during Post-Ingest" unless failed_objects.empty?
    info "Config ##{cfg.id} processed. Elapsed time: #{elapsed_time(start_time)}."
    Application.log_end(cfg)
    Application.log_end cfg.ingest_run
    
  end # process_config

  def process_object(obj)
    
    Application.log_to(obj)
    info "Processing object ##{obj.id}"
    
    obj.set_status_recursive Status::PostIngesting, Status::Ingested
    obj.save
    
    ### link the accessright records
    link_ar obj.get_config, obj
    
    ### link the dc metadata records
    create_and_link_dc obj
    
    obj.set_status_recursive Status::PostIngested, Status::PostIngesting
    
  rescue => e
    obj.status = Status::PostIngestFailed
    handle_exception e
   
  ensure
    obj.save
    Application.log_end(obj)
    
  end # process_object
  
  def link_ar(cfg, obj)
    obj.children.each       { |c| link_ar cfg, c }
    return unless obj.pid
    obj.manifestations.each { |m| link_ar cfg, m }
    ar = cfg.get_protection obj.usage_type
    return if ar.nil?
    case ar.ptype
    when :CUSTOM
      if ar.mid.nil?
        acl_record = MetaDataManager.instance.create_acl_record(ar.pinfo)
        result = MetaDataManager.instance.create_acl acl_record
        unless result[:error].empty? && result[:mids].size == 1
          result[:error].each { |error| @app.logger.error "Error calling web service: #{error}" }
          error "Failed to create accessrights metadata for #{ar.inspect}"
          obj.status = Status::PostIngestFailed
        end
        ar.mid = result[:mids][0]
        ar.save
        info "Created accessrights metadata record #{ar.mid} for protection ##{ar.id}"
      end
    when :WATERMARK
      return
    end
    if ar.mid.nil?
      error "Could not link accessright to object #{obj.pid}"
      obj.status = Status::PostIngestFailed
      return
    end
    result = DigitalEntityManager.instance.link_acl obj.pid, ar.mid
    unless result[:error].empty?
      result[:error].each { |e| error "Error calling web service: #{e}" }
      error "Failed to link accessright #{ar.mid} to object #{obj.pid}"
      obj.status = Status::PostIngestFailed
    else
      info "Linked accessright #{ar.mid} to object #{obj.pid}"
    end
  end
  
  def create_and_link_dc( obj, mid = nil )
    return unless (obj.metadata or mid) and obj.pid
    unless mid
      result = MetaDataManager.instance.create_dc_from_xml(obj.metadata)
      result[:error].each { |e| error "Error calling web service: #{e}"}
      if result[:mids].empty?
        error "Failed to create DC metadata for object #{obj.pid}"
        obj.status = Status::PostIngestFailed
        return
      end
      mid = result[:mids].first
      info "Created DC metadata record nr #{mid}"
    end
    return unless mid
    result = DigitalEntityManager.instance.link_dc obj.pid, mid
    result[:error].each { |error| error "Error calling web service: #{error}"}
    unless result[:error].empty?
      error "Failed to link metadata record #{mid} to object #{obj.pid}"
      obj.status = Status::PostIngestFailed
    else
      info "Attached DC metadata #{mid} to object #{obj.pid}"
      obj.metadata_mid = mid
    end
    obj.manifestations.each { |m| create_and_link_dc m, mid }
    obj.children.each       { |c| create_and_link_dc c, mid }
  end
  
  def undo_config( cfg )
    start_time = Time.now
    info "Undo configuration ##{cfg.id} PostIngest."
    cfg.root_objects.each do |obj|
      obj.set_status_recursive Status::PostIngesting
      undo_object cfg, obj
      obj.set_status_recursive Status::Ingested, Status::PostIngesting
      obj.save
    end
    cfg.status = Status::Ingested
    cfg.save
    info "Configuration ##{cfg.id} PostIngest undone. Elapsed time: #{elapsed_time(start_time)}."
  end
  
  def undo_object( cfg, obj )
    info "Undo object ##{obj.id} PostIngest."
    unlink_ar cfg, obj
    unlink_and_delete_dc obj
    info "Object ##{obj.id} PostIngest undone."
  end
  
  def unlink_and_delete_dc( obj )
    obj.children.each       { |c| unlink_and_delete_dc c }
    return unless obj.pid and obj.metadata_mid
    obj.manifestations.each { |m| unlink_and_delete_dc m }
    mid = obj.metadata_mid
    result = DigitalEntityManager.instance.unlink_dc obj.pid, mid
    result[:error].each { |error| error "Error calling web service: #{error}"}
    unless result[:error].empty?
      error "Failed to unlink metadata record #{mid} to object #{obj.pid}"
      obj.status = Status::PostIngestFailed
    else
      info "Removed DC metadata #{mid} from object #{obj.pid}"
      result = MetaDataManager.instance.delete mid
      if result[:error].empty?
        info "Deleted DC record #{mid}."
        IngestObject.all(:metadata_mid => mid) do |o|
          debug "Clearing metadata_mid field for object ##{o.id}"
          o.metadata_mid = nil
        end
      end
    end
  end
  
  def unlink_ar(cfg, obj)
    obj.children.each       { |c| unlink_ar cfg, c }
    return unless obj.pid
    obj.manifestations.each { |m| unlink_ar cfg, m }
    ar = cfg.get_protection obj.usage_type
    return if ar.nil?
    return if ar.mid.nil?
    result = DigitalEntityManager.instance.unlink_acl obj.pid, ar.mid
    unless result[:error].empty?
      result[:error].each { |e| error "Error calling web service: #{e}" }
      error "Failed to unlink accessright #{ar.mid} from object #{obj.pid}"
      obj.status = Status::PostIngestFailed
    else
      info "Unlinked accessright #{ar.mid} from object #{obj.pid}"
      if ar.ptype == :CUSTOM
        # try to delete the ar object
        result = MetaDataManager.instance.delete ar.mid
        if result[:error].empty?
          info "Deleted accessright metadata record #{ar.mid}."
          ar.mid = nil
        end
        # We ignore errors, AR record may very well still be in use
      end
    end
  end
  
end
