# coding: utf-8

require 'ingester_module'
require 'webservices/digital_entity_manager'
require 'webservices/meta_data_manager'

#noinspection RubyResolve
class PostIngester
  include IngesterModule
  
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
    
  end # start_queue
  
  def start( config_id )
    
    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless (cfg = IngestConfig.first(:id => config_id))
    
    begin
      
      ApplicationStatus.instance.run = cfg.ingest_run
      ApplicationStatus.instance.cfg = cfg
      
      case cfg.status
      when Status::Idle ... Status::Ingested
        # Oops! Not yet ready.
        error "Cannot yet PostIngest configuration ##{config_id}. Status is '#{Status.to_string(cfg.status)}'."
      when Status::Ingested ... Status::PostIngesting
        # Excellent! Continue ...
        process_config cfg
      when Status::PostIngesting ... Status::PostIngested
        info "PostIngest of configuration ##{config_id} failed the last time. The current status is unreliable, so we restart."
        process_config cfg
      when Status::PostIngested
        if cfg.root_objects.all? { |obj| obj.status >= Status::PostIngested }
          warn "Skipping PostIngest of configuration ##{config_id} because all objects are PostIngested."
        else
          info "Continuing PostIngest of configuration #{config_id}. Some objects are not yet PostIngested."
          continue cfg
        end
      else
        warn "Skipping PostIngest of configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
      end
      
    ensure
      ApplicationStatus.instance.cfg = nil
      ApplicationStatus.instance.run = nil
      
    end
    
    config_id
    
  end # start
  
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
    
    if (cfg = undo(config_id))
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
    ApplicationStatus.instance.run = cfg.ingest_run
    ApplicationStatus.instance.cfg = cfg
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
    ApplicationStatus.instance.cfg = nil
    ApplicationStatus.instance.run = nil
    
  end # process_config

  def process_object(obj)
    
    ApplicationStatus.instance.obj = obj
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
    ApplicationStatus.instance.obj = nil
    
  end # process_object
  
  def link_ar(cfg, obj)
    obj.children.each       { |c| link_ar cfg, c }
    return unless obj.pid
    obj.manifestations.each { |m| link_ar cfg, m }
    ar = obj.get_accessright
    return if ar.nil?
    return if ar.is_watermark?
    if ar.is_custom?
      if ar.get_id.nil?
        acl_record = MetaDataManager.instance.create_acl_record(ar.get_custom)
        result = MetaDataManager.instance.create_acl acl_record
        result[:error].each { |error| Application.instance.logger.error "Error calling web service: #{error}" } if result[:error]
        if result[:mids] and result[:mids].size == 1
          ar.set_id result[:mids][0]
          ar.save
          info "Created accessrights metadata record #{ar.get_id} for accessright ##{ar.id}"
        else
          error "Failed to create accessrights metadata for #{ar.inspect}"
          obj.status = Status::PostIngestFailed
        end
      end
    end
    if ar.get_id.nil?
      error "Could not link accessright to object #{obj.pid}"
      obj.status = Status::PostIngestFailed
      return
    end
    result = DigitalEntityManager.instance.link_acl obj.pid, ar.get_id
    if result[:error]
      result[:error].each { |e| error "Error calling web service: #{e}" }
      error "Failed to link accessright #{ar.get_id} to object #{obj.pid}"
      obj.status = Status::PostIngestFailed
    else
      info "Linked accessright #{ar.get_id} to object #{obj.pid}"
    end
  end

  def create_and_link_dc( obj, mid = nil )
    if obj.metadata
      if obj.pid
        result = MetaDataManager.instance.create_dc_from_xml(obj.metadata)
        result[:error].each { |e| error "Error calling web service: #{e}" } if result[:error]
        unless result[:mids] and !result[:mids].empty?
          error "Failed to create DC metadata for object #{obj.pid}"
          obj.status = Status::PostIngestFailed
          return
        end
        mid = result[:mids].first
        info "Created DC metadata record nr #{mid}"
      else
        warn "Ignoring metadata on virtual object ##{obj.id}: '#{obj.label_path}'"
      end
    end
    if mid and obj.pid
      result = DigitalEntityManager.instance.link_dc obj.pid, mid
      if result[:error]
        result[:error].each { |e| error "Error calling web service: #{e}"}
        error "Failed to link metadata record #{mid} to object #{obj.pid}"
        obj.status = Status::PostIngestFailed
      else
        info "Attached DC metadata #{mid} to object #{obj.pid}"
        obj.metadata_mid = mid
      end
    end
    obj.manifestations.each { |m| create_and_link_dc m, mid }
    obj.children.each       { |c| create_and_link_dc c }
  end

  def undo_config( cfg )
    start_time = Time.now
    ApplicationStatus.instance.run = cfg.ingest_run
    ApplicationStatus.instance.cfg = cfg
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
    ApplicationStatus.instance.cfg = nil
    ApplicationStatus.instance.run = nil
  end
  
  def undo_object( cfg, obj )
    ApplicationStatus.instance.obj = obj
    info "Undo object ##{obj.id} PostIngest."
    unlink_ar cfg, obj
    unlink_and_delete_dc obj
    info "Object ##{obj.id} PostIngest undone."
    ApplicationStatus.instance.obj = nil
  end
  
  def unlink_and_delete_dc( obj )
    obj.children.each       { |c| unlink_and_delete_dc c }
    return unless obj.pid and obj.metadata_mid
    obj.manifestations.each { |m| unlink_and_delete_dc m }
    mid = obj.metadata_mid
    result = DigitalEntityManager.instance.unlink_dc obj.pid, mid
    result[:error].each { |error| error "Error calling web service: #{error}"} if result[:error]
    if result[:error].nil? or result[:error].empty?
      info "Removed DC metadata #{mid} from object #{obj.pid}"
      result = MetaDataManager.instance.delete mid
      if result[:error].nil? or result[:error].empty?
        info "Deleted DC record #{mid}."
        IngestObject.all(:metadata_mid => mid) do |o|
          debug "Clearing metadata_mid field for object ##{o.id}"
          o.metadata_mid = nil
        end
      end
    else
      error "Failed to unlink metadata record #{mid} to object #{obj.pid}"
      obj.status = Status::PostIngestFailed
    end
  end
  
  def unlink_ar(cfg, obj)
    obj.children.each       { |c| unlink_ar cfg, c }
    return unless obj.pid
    obj.manifestations.each { |m| unlink_ar cfg, m }
    ar = obj.get_accessright
    return unless ar && ar.get_id
    result = DigitalEntityManager.instance.unlink_acl obj.pid, ar.get_id
    if result[:error].nil? or result[:error].empty?
      info "Unlinked accessright #{ar.get_id} from object #{obj.pid}"
      if ar.is_custom?
        # try to delete the ar object
        result = MetaDataManager.instance.delete ar.get_id
        if result[:error].nil? or result[:error].empty?
          info "Deleted accessright metadata record #{ar.get_id}."
          ar.set_id nil
        end
        # We ignore errors, AR record may very well still be in use
      end
    else
      result[:error].each { |e| error "Error calling web service: #{e}" }
      error "Failed to unlink accessright #{ar.get_id} from object #{obj.pid}"
      obj.status = Status::PostIngestFailed
    end
  end
  
end
