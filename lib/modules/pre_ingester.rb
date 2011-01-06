require 'application'
require 'ingest_models/model_factory'
require 'tools/ingest_settings'
require 'tools/csv_file'
require 'modules/metadata'

class PreIngester
  include ApplicationTask

  def start
    info 'Starting'

    cfg_queue = IngestConfig.all(:status => Status::PreProcessed)

    cfg_queue.each do |cfg|

      process_config cfg if cfg.status == Status::PreProcessed

    end # cfg_queue.each

  rescue Exception => e
    handle_exception e

  ensure
    info 'Done'

  end

  def restart( config_id )
    
    cfg = IngestConfig.first(:id => config_id)

    if cfg.nil?
      error "Configuration ##{config_id} not found"
      return
    end

    if cfg.status <= Status::PreProcessed
      error "Configuration ##{config_id} did not yet start PreIngest"
      return
    elsif cfg.status == Status::PreIngestFailed
      # continue
    elsif cfg.status >= Status::PreIngested
      warn "Configuration ##{config_id} finished PreIngesting. Restarting ..."
      cfg.status = Status::PreProcessed
    end

    process_config cfg, true

  end

  def process_config( cfg, continue = false )

    Application.log_to(cfg)
    info "Processing config ##{cfg.id}"

    cfg.status = Status::PreIngesting

    failed_objects = []

    setup_ingest cfg, continue != true

    cfg.root_objects.each do |obj|

      process_object obj if obj.status == Status::PreProcessed

      add_to_csv obj if obj.status == Status::PreIngested

      failed_objects << obj if obj.status == Status::PreIngestFailed

    end # cfg.ingest_objects.each

    finalize_ingest cfg

  rescue Exception => e
    cfg.status = Status::PreIngestFailed
    handle_exception e

  ensure
    cfg.status = Status::PreIngested
    cfg.save
    warn "#{failed_objects.size} objects failed during Pre-Ingest" unless failed_objects.empty?
    Application.log_end cfg

  end # process_config

  def process_object( obj )

    Application.log_to(obj)

    info "Processing object ##{obj.id}"

    obj.status = Status::PreIngesting

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
#    obj.save
    Application.log_end(obj)

  end # process_object

  private

  def setup_ingest( cfg, clear_dir )
    setup_ingest_dir cfg, clear_dir
    create_ingest_settings cfg
  end

  def finalize_ingest( cfg )

    # write ingest_settings
    @ingest_settings.write cfg.ingest_dir + '/ingest_settings.xml'

    # write csv file
    @csv.write "#{cfg.ingest_dir}/transform/values.csv"

    # write mapping file
    @csv.write_mapping "#{cfg.ingest_dir}/transform/mapping.xml"

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

  def create_ingest_settings( cfg )
    info 'Preparing ingest settings'
    @ingest_settings = IngestSettings.new
    @ingest_settings.add_control_fields cfg.get_control_fields, ''
    @csv = CsvFile.new

  end

  def get_metadata( object )
    cfg = object.get_config
    md = Metadata.new(object)
    result = false
    if mf = cfg.metadata_file
      result = md.get_from_disk mf
    else
      result = md.get_from_aleph cfg.get_search_options
    end
    result
  end

  def copy_stream( object )
    if object.file_info
      info "Copying original stream '#{object.file_path}'"
      object.file_stream = "#{object.get_config.ingest_dir}/transform/streams/#{object.file_name}"
      FileUtils.cp_r object.file_path, object.file_stream
    end
    object.children.each { |child| copy_stream child }
  end

  def create_manifestations( object )
    cfg = object.get_config
    model = ModelFactory.instance.get_model_for_config cfg
    ModelFactory.generated_manifestations.each do |m|
      file = model.create_manifestation object, m, "#{cfg.ingest_dir}/transform/streams/"
      if file
        info "Created manifestation file: #{file}"
        mobj = IngestObject.new
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
    model = ModelFactory.instance.get_model_for_config cfg

    # note: original will never be watermark protected
    object.manifestations.each do |manifestation|
      p = cfg.get_protection(manifestation.usage_type)
      next unless p and p.ptype == :WATERMARK # only watermark protection is done at this stage
      format = model.get_manifestation(manifestation.usage_type)[:FORMAT]
      converter = model.get_converter manifestation.file_stream
      if converter.respond_to?(:watermark)
        wm_file = p.pinfo
        wm_file = converter.create_watermark(p.pinfo, cfg.ingest_dir, manifestation.usage_type) unless File.exist?(wm_file)
        new_file = File.dirname(manifestation.file_stream) + '/' +
          File.basename(manifestation.file_stream, '.*') + '_watermark.' +
          converter.type2ext(format)
        converter.watermark manifestation.file_stream, new_file, wm_file
        info "Created file #{new_file} for watermark protection of #{manifestation.usage_type}"
        File.delete(manifestation.file_stream)
        manifestation.file_stream = new_file
      else
        error 'Watermark requested, but not supported for the file type'
      end
    end
    object.children.each { |child| create_watermark child }
  end

  def add_to_csv( object )
    if (object.root? and object.parent?)
      object.vpid = @csv.add_complex_object object.label, object.usage_type
    else
      object.vpid = @csv.add_file File.basename(object.file_stream.to_s), object.label, object.usage_type, ''
      @csv.set_relation object.vpid, 'part_of', object.parent.vpid if object.child?
    end
    @csv.set_relation object.vpid, 'manifestation', object.master.vpid if object.manifestation?
    object.manifestations.each { |obj| add_to_csv obj }
    object.children.each       { |obj| add_to_csv obj }
  end

end
