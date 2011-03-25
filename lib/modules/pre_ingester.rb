require 'lib/application_task'
require 'lib/ingest_models/model_factory'
require 'lib/tools/ingester_setup'
require_relative 'metadata'

class PreIngester
  include ApplicationTask
  
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
  
  def start( config_id )
    
    begin
      error "Configuration ##{config_id} not found"
      return nil
    end unless cfg = IngestConfig.first(:id => config_id)
    
    begin
      
      Application.log_to cfg.ingest_run
      Application.log_to cfg
      
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
    
    unless Status.phase(cfg.status) == Status::PreIngest
      Application.log_to cfg.ingest_run
      Application.log_to cfg
      warn "Cannot undo configuration ##{config_id} because status is '#{Status.to_string(cfg.status)}'."
      Application.log_end cfg
      Application.log_end cfg.ingest_run
      return cfg if cfg.status == Status::PreProcessed
      return nil
    end
    
    undo_config cfg
    
  end
  
  def restart( config_id )
    
    if cfg = undo(config_id)
      Application.log_to cfg.ingest_run
      Application.log_to cfg
      info "Restarting config ##{config_id}"
      process_config cfg, false
      Application.log_end cfg
      Application.log_end cfg.ingest_run
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
    
    begin
      
      Application.log_to cfg.ingest_run
      Application.log_to cfg
      
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
      Application.log_end cfg
      Application.log_end cfg.ingest_run
      
    end
    
    return config_id
    
  end
  
  private
  
  def process_config( cfg, continue = false )
    
    start_time = Time.now
    Application.log_to cfg.ingest_run
    Application.log_to(cfg)
    info "Processing config ##{cfg.id}"
    
    cfg.status = Status::PreIngesting
    cfg.save
    
    failed_objects = []
    
    setup_ingest cfg, continue != true
    
    valid_states = [Status::PreProcessed]
    if continue
      valid_states << Status::PreIngesting
      valid_states << Status::PreIngestFailed
    end

    @model = ModelFactory.instance.get_model_for_config cfg
    @metadata = Metadata.new cfg
    
    cfg.root_objects.each do |obj|
      
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
    Application.log_end cfg
    Application.log_end cfg.ingest_run
    
  end # process_config
  
  def process_object( obj )
    
    Application.log_to(obj)
    
    info "Processing object ##{obj.id}"
    
    obj.status = Status::PreIngesting
    obj.save
    
    # get metadata
    info 'Getting metadata'
    result = get_metadata obj
    
    # copy stream to ingest_dir
    copy_stream obj
    
    # create manifestations
    info 'Creating manifestations'
    create_manifestations obj
    
    # watermark objects
    create_watermark obj
    
    # set object status to preingested
    obj.set_status_recursive Status::PreIngested
    
  rescue Exception => e
    obj.status = Status::PreIngestFailed
    print_exception e
    
  ensure
    obj.save
    Application.log_end(obj)
    
  end # process_object
  
  private
  
  def setup_ingest( cfg, clear_dir )
    setup_ingest_dir cfg, clear_dir
    create_ingester_setup cfg
  end
  
  def finalize_ingest( cfg )
    
    cfg.mets = @ingester_setup.requires_mets
    cfg.complex = !cfg.mets
    @ingester_setup.finalize_setup cfg.ingest_dir
    
  end
  
  def setup_ingest_dir( cfg, clear_dir )
    
    cfg.ingest_id = "#{ConfigFile['ingest_name']}_#{format('%d',cfg.id)}"
    
    load_dir = "#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_ingest_dir']}/load_#{cfg.ingest_id}"
    unless cfg.work_dir.nil?
      FileUtils.mkdir(cfg.work_dir) unless Dir.exist?(cfg.work_dir)
      cfg.ingest_dir = "#{cfg.work_dir}/load_#{cfg.ingest_id}"
      FileUtils.rm_r("#{load_dir}", :force => true) if clear_dir
      FileUtils.ln_s(cfg.ingest_dir, load_dir, :force => true) unless File.exist? load_dir
    else
      cfg.ingest_dir = load_dir
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
    end
    
  end
  
  def create_ingester_setup( cfg )
    info 'Preparing ingester setup'
    @ingester_setup = IngesterSetup.new
    @ingester_setup.add_control_fields cfg.get_control_fields, ''
  end
  
  def get_metadata( object )
    result = @metadata.get_dc_record(object)
    object.children.each{ |child| get_metadata child }
    result
  end
  
  def copy_stream( object )
    if object.file_info
      info "Copying original stream '#{object.file_path}'"
      object.file_stream = "#{object.get_config.ingest_dir}/transform/streams/#{object.flattened_relative}"
#      FileUtils.mkdir_p File.dirname(object.file_stream)
      FileUtils.cp_r object.file_path, object.file_stream
    end
    object.children.each { |child| copy_stream child }
  end
  
  def create_manifestations( object )
    cfg = object.get_config
    ModelFactory.generated_manifestations.each do |m|
      file = @model.create_manifestation object, m, "#{cfg.ingest_dir}/transform/streams/"
      if file
        info "Created manifestation file: #{file}"
        mobj = IngestObject.new file, :MD5
        mobj.file_stream = file
        mobj.usage_type = m
        mobj.label = object.label
        mobj.status = Status::PreIngested
        object.add_manifestation mobj
      end
    end
    object.children.each { |child| create_manifestations child }
  end
  
  def create_watermark( object )
    cfg = object.get_config
    
    # note: original will never be watermark protected
    object.manifestations.each do |manifestation|
      p = cfg.get_protection(manifestation.usage_type)
      next unless p and p.ptype == :WATERMARK # only watermark protection is done at this stage
      converter = @model.get_converter manifestation.file_stream
      if converter.respond_to?(:watermark)
        wm_file = p.pinfo
        wm_file = converter.create_watermark(p.pinfo, cfg.ingest_dir, manifestation.usage_type) unless File.exist?(wm_file)
        new_file = File.dirname(manifestation.file_stream) + '/' +
          File.basename(manifestation.file_stream, '.*') + '_watermark' + File.extname(manifestation.file_stream)
        converter.watermark manifestation.file_stream, new_file, wm_file
        info "Created file #{new_file} for watermark protection of #{manifestation.usage_type}"
        File.delete(manifestation.file_stream)
        manifestation.file_stream = new_file
        manifestation.file_info.file_path = new_file if manifestation.file_info
      else
        error 'Watermark requested, but not supported for the file type'
      end
    end
    object.children.each { |child| create_watermark child }
  end
  
  def add_to_ingest( object )
    if (object.root? and object.parent?)
      object.vpid = @ingester_setup.add_complex_object object.label, object.usage_type
    else
      object.vpid = @ingester_setup.add_file object.label, object.usage_type, '', object
      @ingester_setup.set_relation object.vpid, 'part_of', object.parent.vpid if object.child?
    end
    @ingester_setup.set_relation object.vpid, 'manifestation', object.master.vpid if object.manifestation?
    object.manifestations.each { |obj| add_to_ingest obj }
    object.children.each       { |obj| add_to_ingest obj }
    object.save
  end
  
  def delete_ingest_dir( cfg )
    load_dir = "#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_ingest_dir']}/load_#{cfg.ingest_id}"
      FileUtils.rm_r "#{load_dir}", :force => true
      if load_dir != cfg.ingest_dir
        FileUtils.rm_r cfg.ingest_dir, :force => true
      end
  end
  
  def undo_config( cfg )
    start_time = Time.now
    info "Undo configuration ##{cfg.id} PreIngest."
    cfg.root_objects.each do |obj|
      undo_object obj
    end
    delete_ingest_dir cfg
    cfg.ingest_dir = nil
    cfg.status = Status::PreProcessed
    cfg.save
    info "Configuration ##{cfg.id} PreIngest undone. Elapsed time: #{elapsed_time(start_time)}."
    cfg
  end
  
  def undo_object( obj )
    info "Undo object ##{obj.id} PreIngest."
    obj.vpid = nil
    obj.children.each { |child| undo_object child }
    obj.manifestations.each { |m| m.delete }
    obj.status = Status::PreProcessed
    obj.clear_metadata
    obj.clear_filestream
    obj.save
    info "Object ##{obj.id} PreIngest undone."
  end
  
end
