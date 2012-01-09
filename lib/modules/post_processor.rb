require "ingester_module"

class PostProcessor
  include IngesterModule

  def start( config_id )

    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless cfg = IngestConfig.first(:id => config_id)

    begin

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
      end

    ensure
      cfg.status = Status::PostProcessed
      cfg.save

      ApplicationStatus.instance.cfg = nil
      ApplicationStatus.instance.run = nil

    end

    config_id

  end

  def undo( config_id )

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

    process_config cfg

    config_id

  end

  protected

  def process_config( cfg )

  end

  def undo_config( cfg )
    cfg.status == Status::PostIngested
    cfg.save
  end

end