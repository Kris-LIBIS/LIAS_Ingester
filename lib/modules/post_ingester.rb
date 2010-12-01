require 'application'
require 'webservices/digital_entity_manager'
require 'webservices/meta_data_manager'

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

  def process_config(cfg)

    Application.log_to(cfg)
      info "Processing config ##{cfg.id}"

      cfg.status = Status::PostIngesting

# For some strange reason the statement below does not work
#      cfg.ingest_objects.all(:status => Status::Ingested) do |obj|

# But this does work !?!?:
      cfg.root_objects.each do |obj|

        next unless obj.status == Status::Ingested

        process_object obj

      end # ingest_objects.all

      cfg.status = Status::Done if cfg.check_object_status(Status::Done)

    rescue => e
      handle_exception e

    ensure
      cfg.save
      Application.log_end(cfg)

  end # process_config

  def process_object(obj)

    Application.log_to(obj)
    info "Processing object ##{obj.id}"

    ### link the accessright records
    link_ar obj.ingest_config, obj

    ### link the dc metadata records
    create_and_link_dc obj

    obj.set_status_recursive Status::Done, Status::Ingested

  rescue => e
    obj.set_status_recursive Status::Done, Status::PostIngestFailed
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
