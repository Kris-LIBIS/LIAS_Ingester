require "ingester_module"
require "webservices/collective_access"

#noinspection RubyResolve
class PostProcessor
  include IngesterModule

  THUMBNAIL_URL = 'http://libis-t-rosetta-1.libis.kuleuven.be/lias/cgi/get_pid?redirect&usagetype=THUMBNAIL&custom_att_3=stream&pid='
  VIEW_URL = 'http://libis-t-rosetta-1.libis.kuleuven.be/lias/cgi/get_pid?redirect&usagetype=VIEW_MAIN,VIEW&pid='

  def start(config_id)

    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless (cfg = IngestConfig.first(:id => config_id))

    begin

      #noinspection RubyResolve
      ApplicationStatus.instance.run = cfg.ingest_run
      ApplicationStatus.instance.cfg = cfg

      case cfg.status
        when Status::Idle ... Status::PostIngested
          # Oops! Not yet ready.
          error "Cannot yet PostProcess configuration ##{config_id}. Status is '#{Status.to_string(cfg.status)}'."
        when Status::PostIngested ... Status::PostProcessing
          # Excellent! Continue ...
          process_config cfg
        when Status::PostProcessing ... Status::PostProcessed
          info "PostProcess of configuration ##{config_id} failed the last time. The current status is unreliable, so we restart."
          process_config cfg
        when Status::PostProcessed ... Status::Finished
          if cfg.root_objects.all? { |obj| obj.status >= Status::PostProcessed }
            warn "Skipping PostProcess of configuration ##{config_id} because all objects are PostProcessed."
          else
            info "Continuing PostProcess of configuration #{config_id}. Some objects are not yet PostProcessed."
            continue cfg.id
          end
        when Status::Finished
          warn "Skipping PostProcess of configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
        else
          # nothing
      end

    ensure
      cfg.status = Status::PostProcessed
      cfg.save

      ApplicationStatus.instance.cfg = nil
      ApplicationStatus.instance.run = nil

    end

    config_id

  end

  def undo(config_id)

    cfg = IngestConfig.first(:id => config_id)

    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end

    unless Status.phase(cfg.status) == Status::PostProcess
      warn "Cannot undo configuration ##{config_id} because status is #{Status.to_string(cfg.status)}."
      return cfg if cfg.status == Status::PostIngested
      return nil
    end

    undo_config cfg

    cfg

  end

  def restart(config_id)

    if (cfg = undo(config_id))
      info "Restarting config ##{config_id}"
      process_config cfg
      return config_id
    end

    nil

  end

  def continue(config_id)

    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless (cfg = IngestConfig.first(:id => config_id))

    process_config cfg

    config_id

  end

  protected

  def process_config(cfg)
    start_time = Time.now
    ApplicationStatus.instance.run = cfg.ingest_run
    ApplicationStatus.instance.cfg = cfg
    info "Processing config ##{cfg.id}"

    cfg.status = Status::PostProcessing
    cfg.save

    failed_objects = []

    @client = nil
    case cfg.get_link_type
      when :CollectiveAccess
        @client = CollectiveAccess.new cfg.get_link_options[:host]
        unless @client.authenticate cfg.get_link_options[:user], cfg.get_link_options[:password]
          error "Could not login to CollectiveAccess."
          cfg.status = Status::PostProcessFailed
          return
        end
      else
        # do nothing
    end

    cfg.objects.each do |obj|

      next unless obj.status == Status::PostIngested

      process_object obj

      failed_objects << obj unless obj.status == Status::PostProcessed

    end # ingest_objects.all

    cfg.status = Status::PostProcesed

  rescue => e
    cfg.status = Status::PostProcessingFailed
    handle_exception e

  ensure
    cfg.save
    warn "#{failed_objects.size} objects failed during Post-Process" unless failed_objects.empty?
    info "Config ##{cfg.id} processed. Elapsed time: #{elapsed_time(start_time)}."
    ApplicationStatus.instance.cfg = nil
    ApplicationStatus.instance.run = nil

  end

  def process_object(obj)
    obj.status = Status::PostProcessing
    cfg = obj.ingest_config

    case cfg.get_link_type
      when :CollectiveAccess
        ca_object = @client.get_object(obj.label)
        ca_object = @client.add_object(obj.label) unless ca_object
        unless ca_object
          error "Failed to get and/or create the Collective Access record for object ##{obj.id}."
          obj.status = Status::PostProcessFailed
          return
        end
        ca_object.delete_attribute :digitoolUrl
        result = ca_object.add_attribute :digitooUrl, "#{obj.pid}_,_#{THUMBNAIL_URL}#{obj.pid}_,_#{VIEW_URL}#{obj.pid}"
        unless result
          error "Failed to add the Digitool link to the Collective Access record for object ##{obj.id}."
          obj.status = Status::PostProcessFailed
          return
        end
      else
        # do nothing
    end

  ensure
    obj.save

  end

  def undo_config(cfg)
    cfg.status == Status::PostIngested
    cfg.save
  end

end