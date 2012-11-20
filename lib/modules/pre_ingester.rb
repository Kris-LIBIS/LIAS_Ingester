# coding: utf-8

require 'ingester_module'
require 'ingest_models/ingest_model_factory'
require 'tools/ingester_setup'
require_relative 'metadata'

class PreIngester
  include IngesterModule

  def start_queue
    info 'Starting'

    cfg_queue = IngestConfig.all(:status => Status::PreProcessed)

    cfg_queue.each do |cfg|

      process_config cfg, false

    end # cfg_queue.each

  rescue Exception => e
    handle_exception e

  ensure
    info 'Done'

  end

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
        when Status::Idle ... Status::PreProcessed
          # Oops! Not yet ready.
          error "Cannot yet PreIngest configuration ##{config_id}. Status is '#{Status.to_string(cfg.status)}'."
        when Status::PreProcessed ... Status::PreIngesting
          # Excellent! Continue ...
          process_config cfg, false
        when Status::PreIngesting ... Status::PreIngested
          info "PreIngest of configuration ##{config_id} failed the last time. The current status is unreliable, so we restart."
          process_config cfg, false
        when Status::PreIngested ... Status::Ingesting
          if cfg.root_objects.all? { |obj| obj.status >= Status::PreIngested }
            warn "Skipping PreIngest of configuration ##{config_id} because all objects are PreIngested."
          else
            info "Continuing PreIngest of configuration #{config_id}. Some objects are not yet PreIngested."
            continue cfg
          end
        when Status::Ingesting .. Status::Finished
          warn "Skipping PreIngest of configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
        else
      end

    ensure
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

    unless Status.phase(cfg.status) == Status::PreIngest
      #noinspection RubyResolve
      ApplicationStatus.instance.run = cfg.ingest_run
      ApplicationStatus.instance.cfg = cfg
      warn "Cannot undo configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
      ApplicationStatus.instance.cfg = nil
      ApplicationStatus.instance.run = nil
      return cfg if cfg.status == Status::PreProcessed
      return nil
    end

    undo_config cfg

  end

  def restart(config_id)

    if (cfg = undo(config_id))
      #noinspection RubyResolve
      ApplicationStatus.instance.run = cfg.ingest_run
      ApplicationStatus.instance.cfg = cfg
      info "Restarting config ##{config_id}"
      process_config cfg, false
      ApplicationStatus.instance.cfg = nil
      ApplicationStatus.instance.run = nil
      return config_id
    end

    nil

  end

  def continue(config_id)

    cfg = IngestConfig.first(:id => config_id)

    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return nil
    end

    begin

      #noinspection RubyResolve
      ApplicationStatus.instance.run = cfg.ingest_run
      ApplicationStatus.instance.cfg = cfg

      case cfg.status
        when Status::Idle ... Status::PreProcessed
          error "Configuration ##{config_id} not yet ready for PreIngest. Status is '#{Status.to_string(cfg.status)}'."
          config_id = nil
        when Status::PreProcessed .. Status::PreIngested
          # OK, continue the PreIngest
          process_config cfg, true
        else
          warn "Configuration ##{config_id} allready finished PreIngesting."
      end

    ensure
      ApplicationStatus.instance.cfg = nil
      ApplicationStatus.instance.run = nil

    end

    config_id

  end

  private

  def process_config(cfg, continue = false)

    start_time = Time.now
    #noinspection RubyResolve
    ApplicationStatus.instance.run = cfg.ingest_run
    ApplicationStatus.instance.cfg = cfg
    info "Processing config ##{cfg.id}"

    cfg.status = Status::PreIngesting
    cfg.save

    failed_objects = []

    setup_ingest cfg, !continue

    valid_states = [Status::PreProcessed]
    if continue
      valid_states << Status::PreIngesting
      valid_states << Status::PreIngestFailed
    end

    @metadata = Metadata.new cfg

    cfg.root_objects.each do |obj|

      unless obj.status == Status::PreProcessed
        info "Skipping object ##{obj.id} - Invalid status"
      end

      process_object obj if valid_states.include?(obj.status)

      add_to_ingest obj if obj.status == Status::PreIngested

      failed_objects << obj if obj.status == Status::PreIngestFailed

    end # cfg.ingest_objects.each

    finalize_ingest cfg

    cfg.status = Status::PreIngested

  rescue Exception => e
    cfg.status = Status::PreIngestFailed
    print_exception e

  ensure
    cfg.save
    warn "#{failed_objects.size} objects failed during Pre-Ingest" unless failed_objects.empty?
    info "Config ##{cfg.id} processed. Elapsed time: #{elapsed_time(start_time)}."
    ApplicationStatus.instance.cfg = nil
    ApplicationStatus.instance.run = nil

  end

  # process_config

  def process_object(obj)

    ApplicationStatus.instance.obj = obj

    info "Processing object ##{obj.id}"

    obj.status = Status::PreIngesting
    obj.save

    # get metadata
    info 'Getting metadata'
    get_metadata obj

    # copy stream to ingest_dir
    copy_stream obj

    # create manifestations
    info 'Creating manifestations'
    create_manifestations obj

    # set object status to preingested
    obj.set_status_recursive Status::PreIngested

  rescue Exception => e
    obj.status = Status::PreIngestFailed
    print_exception e

  ensure
    obj.save
    ApplicationStatus.instance.obj = nil

  end

  # process_object

  private

  def setup_ingest(cfg, clear_dir)
    setup_ingest_dir cfg, clear_dir
    create_ingester_setup cfg
  end

  #noinspection RubyResolve
  def finalize_ingest(cfg)

    cfg.mets = @ingester_setup.requires_mets?
    cfg.complex = !cfg.mets
    @ingester_setup.finalize_setup cfg.ingest_dir

  end

  #noinspection RubyResolve
  def setup_ingest_dir(cfg, clear_dir)

    cfg.ingest_id = "#{ConfigFile['ingest_name']}_#{format('%d', cfg.id)}"

    load_dir = "#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_ingest_dir']}/load_#{
    cfg.ingest_id}"
    if cfg.work_dir.nil?
      cfg.ingest_dir = load_dir
    else
      FileUtils.mkdir(cfg.work_dir) unless Dir.exist?(cfg.work_dir)
      cfg.ingest_dir = "#{cfg.work_dir}/load_#{cfg.ingest_id}"
      FileUtils.rm_r("#{load_dir}", :force => true) if clear_dir
      FileUtils.ln_s(cfg.ingest_dir, load_dir, :force => true) unless File.exist? load_dir
    end

    info "Setting up ingest directory: #{cfg.ingest_dir}"
    FileUtils.rm_r("#{cfg.ingest_dir}", :force => true) if clear_dir
    FileUtils.mkdir("#{cfg.ingest_dir}") unless Dir.exist?(cfg.ingest_dir)
    dirs = Array.new
    dirs << 'ingest'
    dirs << 'ingest/digital_entities'
    dirs << 'ingest/logs'
    dirs << 'ingest/streams'
    dirs << 'transform'
    dirs << 'transform/digital_entities'
    dirs << 'transform/logs'
    dirs << 'transform/streams'
    dirs.each do |d|
      dir = "#{cfg.ingest_dir}/#{d}"
      FileUtils.mkdir dir unless Dir.exist?(dir)
      FileUtils.chmod 0777, dir
    end

  end

  def create_ingester_setup(cfg)
    info 'Preparing ingester setup'
    @ingester_setup = IngesterSetup.new
    @ingester_setup.add_control_fields cfg.get_control_fields, ''
  end

  def get_metadata(object)
    result = @metadata.get_dc_record(object)
    object.children.each { |child| get_metadata child }
    result
  end

  #noinspection RubyResolve
  def copy_stream(object)
    if object.file_info
      info "Copying original stream '#{object.file_path}'"
      object.file_stream = "#{object.get_config.ingest_dir}/transform/streams/#{object.stream_name}"
#      FileUtils.mkdir_p File.dirname(object.file_stream)
      FileUtils.cp_r object.file_path, object.file_stream
      `touch --reference="#{object.file_path}" "#{object.file_stream}"`
    end
    object.children.each { |child| copy_stream child }
  end

  #noinspection RubyResolve
  def create_manifestations(object)
    if (ingest_model = object.ingest_config.get_ingest_model(object))
      ingest_model.manifestations.each do |m|
        debug "Manifestation: #{m}"
        file = ingest_model.create_manifestation object, m
        if file
          `touch --reference="#{object.file_path}" "#{file}"`
          info "Created manifestation file: #{file}"
          mobj = IngestObject.new file, :MD5
          mobj.file_stream = file
          mobj.usage_type = m
          mobj.label = object.label
          mobj.status = Status::PreIngested
          object.add_manifestation mobj
        end
      end
    else
      warn "No ingest model found for object ##{object.id}"
    end
    object.children.each { |child| create_manifestations child }
  end

  #noinspection RubyResolve
  def add_to_ingest(object)
    if object.root? and object.parent?
      object.vpid = @ingester_setup.add_complex_object object.label, object.usage_type
    else
      object.vpid = @ingester_setup.add_file object.label, object.usage_type, '', object
      @ingester_setup.set_relation object.vpid, 'part_of', object.parent.vpid if object.child?
    end
    @ingester_setup.set_relation object.vpid, 'manifestation', object.master.vpid if object.manifestation?
    object.manifestations.each { |obj| add_to_ingest obj }
    object.children.each { |obj| add_to_ingest obj }
    object.save
  end

  #noinspection RubyResolve
  def delete_ingest_dir(cfg)
    load_dir = "#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_ingest_dir']}/load_#{cfg.ingest_id}"
    FileUtils.rm_r "#{load_dir}", :force => true
    if load_dir != cfg.ingest_dir
      FileUtils.rm_r cfg.ingest_dir, :force => true
    end
  end

  def undo_config(cfg)
    start_time = Time.now
    #noinspection RubyResolve
    ApplicationStatus.instance.run = cfg.ingest_run
    ApplicationStatus.instance.cfg = cfg
    info "Undo configuration ##{cfg.id} PreIngest."
    cfg.root_objects.each do |obj|
      undo_object obj
    end
    delete_ingest_dir cfg
    #noinspection RubyResolve
    cfg.ingest_dir = nil
    cfg.status = Status::PreProcessed
    cfg.save
    info "Configuration ##{cfg.id} PreIngest undone. Elapsed time: #{elapsed_time(start_time)}."
    ApplicationStatus.instance.cfg = nil
    ApplicationStatus.instance.run = nil
    cfg
  end

  def undo_object(obj)
    return if obj.status < Status::PreIngesting
    ApplicationStatus.instance.obj = obj
    info "Undo object ##{obj.id} PreIngest."
    #noinspection RubyResolve
    obj.vpid = nil
    obj.children.each { |child| undo_object child }
    obj.manifestations.each { |m| m.delete }
    obj.status = Status::PreProcessed
    obj.clear_metadata
    obj.clear_filestream
    obj.save
    info "Object ##{obj.id} PreIngest undone."
    ApplicationStatus.instance.obj = nil
  end

end
