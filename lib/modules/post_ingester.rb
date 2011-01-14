require 'lib/webservices/digital_entity_manager'
require 'lib/webservices/meta_data_manager'

class PostIngester
  include ApplicationTask
  
  def start
    
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
  
  def start_config( config_id )
    
    cfg = IngestConfig.first(:id => config_id)
    
    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end
    
    if cfg.status == Status::Ingested
      # continue
    elsif cfg.status == Status::PostIngestFailed
      warn "Configuration ##{config_id} failed before and will now be restarted"
      # continue
    elsif cfg.status >= Status::PostIngested
      warn "Configuration ##{config_id} allready finished PostIngesting."
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
    
    unless Status.phase(cfg.status) == Status.PostIngest
      warn "Cannot undo configuration ##{config_id} because status is #{Status.to_string(cfg.status)}."
      return cfg if cfg.status == Status::Ingested
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
  
  def process_config(cfg)
    
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
    
    cfg.status = Status::Finished
    
  rescue => e
    cfg.status = Status::PostIngestFailed
    handle_exception e
    
  ensure
    cfg.save
    warn "#{failed_objects.size} objects failed during Post-Ingest" unless failed_objects.empty?
    Application.log_end(cfg)
    
  end # process_config

  def process_object(obj)
    
    Application.log_to(obj)
    info "Processing object ##{obj.id}"
    
    obj.status = Status::PostIngesting
    obj.save
    
    ### link the accessright records
    link_ar obj.get_config, obj
    
    ### link the dc metadata records
    create_and_link_dc obj
    
    obj.set_status_recursive Status::PostIngested
    
  rescue => e
    obj.status = Status::PostIngestFailed
    handle_exception e
   
  ensure
    obj.save
    Application.log_end(obj)
    
  end # process_object
  
  def link_ar(cfg, obj)
    return unless obj.pid
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
      return
    end
    result = DigitalEntityManager.instance.link_acl obj.pid, ar.mid
    info "Linked accessright #{ar.mid} to object #{obj.pid}"
    obj.manifestations.each { |m| link_ar cfg, m }
    obj.children.each       { |c| link_ar cfg, c }
  end
  
  def create_and_link_dc( obj, mid = nil )
    return unless obj.metadata and obj.pid
    unless mid
      result = MetaDataManager.instance.create_dc_from_xml(obj.metadata)
      result[:error].each { |error| error "Error calling web service: #{error}"}
      if result[:mids].empty?
        error "Failed to create DC metadata for object #{obj.pid}"
        return
      end
      mid = result[:mids][0]
      info "Created DC metadata record nr #{mid}"
    end
    return unless mid
    result = DigitalEntityManager.instance.link_dc obj.pid, mid
    result[:error].each { |error| error "Error calling web service: #{error}"}
    unless result[:error].empty?
      error "Failed to link metadata record #{mid} to object #{obj.pid}"
      return
    end
    info "Attached DC metadata #{mid} to object #{obj.pid}"
    obj.manifestations.each { |m| create_and_link_dc m, mid }
    obj.children.each       { |c| create_and_link_dc c, mid }
  end
  
end
