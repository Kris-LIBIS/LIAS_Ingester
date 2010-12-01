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

      process_config cfg

    end # cfg_queue.each

  rescue Exception => e
    handle_exception e

  ensure
    info 'Done'

  end

  def process_config( cfg )

    Application.log_to(cfg)
    info "Processing config ##{cfg.id}"

    cfg.status = Status::PreIngesting

    setup_ingest cfg

    cfg.root_objects.each do |obj|

      process_object obj

    end # cfg.ingest_objects.each

    # write ingest_settings
    @ingest_settings.write cfg.ingest_dir + '/ingest_settings.xml'

    # write csv file
    @csv.write "#{cfg.ingest_dir}/transform/values.csv"

    # write mapping file
    @csv.write_mapping "#{cfg.ingest_dir}/transform/mapping.xml"

    cfg.status = Status::PreIngested if cfg.check_object_status(Status::PreIngested)
    cfg.save

  rescue Exception => e
    cfg.status = Status::PreIngestFailed
    handle_exception e

  ensure
    cfg.save
    Application.log_end cfg

  end # process_config

  def process_object( obj )

    Application.log_to(obj)

    info "Processing object ##{obj.id}"

    obj.status = Status::PreIngesting

    # get metadata
    info 'Getting metadata'
    get_metadata obj

    # copy stream to ingest_dir
    copy_stream obj

    # create manifestations
    info 'Creating manifestations'
    create_manifestations obj

    # watermark objects
    create_watermark obj

    # add file to CSV
    add_to_csv obj

    # set object status to preingested
    obj.set_status_recursive Status::PreIngested

  rescue Exception => e
    obj.status = Status::PreIngestFailed
    handle_exception e

  ensure
    obj.save
    Application.log_end(obj)

  end # process_object

  private

  def setup_ingest( cfg )
    # setup ingest_dir
    cfg.ingest_id = "#{ConfigFile['ingest_name']}_#{format('%d',cfg.id)}"
    load_dir = "#{ConfigFile['dtl_base']}/#{ConfigFile['dtl_ingest_dir']}/load_#{cfg.ingest_id}"
    unless cfg.work_dir.nil?
      FileUtils.mkdir(cfg.work_dir) unless Dir.exist?(cfg.work_dir)
      cfg.ingest_dir = "#{cfg.work_dir}/load_#{cfg.ingest_id}"
      FileUtils.rm_r("#{load_dir}", :force => true)
      FileUtils.ln_s(cfg.ingest_dir, load_dir, :force => true)
    else
      cfg.ingest_dir = load_dir
    end
    info "Setting up ingest directory: #{cfg.ingest_dir}"
    FileUtils.rm_r("#{cfg.ingest_dir}", :force => true)
    FileUtils.mkdir("#{cfg.ingest_dir}")
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
      FileUtils.mkdir "#{cfg.ingest_dir}/#{d}"
    end

    # prepare ingest_settings and csv file
    info 'Preparing ingest settings'
    @ingest_settings = IngestSettings.new
    @ingest_settings.add_control_fields cfg.get_control_fields, ''
    @csv = CsvFile.new

  end

  def get_metadata( object )
    cfg = object.ingest_config
    md = Metadata.new(object)
    if mf = cfg.metadata_file
      md.get_from_disk mf
    else
      md.get_from_aleph cfg.get_search_options
    end
  end

  def copy_stream( object )
    if object.file_info
      info "Copying original stream '#{object.file_path}'"
      object.file_stream = "#{object.ingest_config.ingest_dir}/transform/streams/#{object.file_name}"
      FileUtils.cp_r object.file_path, object.file_stream
    end
    object.children.each { |child| copy_stream child }
  end

  def create_manifestations( object )
    cfg = object.ingest_config
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
    cfg = object.ingest_config
    model = ModelFactory.instance.get_model_for_config cfg

    # note: original will never be watermark protected
    object.manifestations.each do |manifestation|
      p = cfg.get_protection(manifestation.usage_type)
      next unless p and p.ptype == :WATERMARK # only watermark protection is done at this stage
      format = model.get_manifestation(manifestation.usage_type)[:FORMAT]
      converter = model.get_converter manifestation.file_stream
      if converter.respond_to?(:watermark)
        converter.watermark p.pinfo
        new_file = File.dirname(manifestation.file_stream) + '/' +
          File.basename(manifestation.file_stream, '.*') + '_watermark.' +
          converter.type2ext(format)
        converter.convert new_file
        info "Created file #{new_file} for watermark protection of #{manifestation.usage_type}"
        File.delete(manifestation.file_stream)
        manifestation.file_stream = new_file
      else
        error 'Watermark requested, but not supported for the file type'
      end
      object.children.each { |child| create_watermark child }
    end
  end

  def add_to_csv( object )
    if (object.root? and object.parent?)
      object.vpid = @csv.add_file File.basename(object.file_stream.to_s), object.label, '', 'COMPLEX'
    else
      object.vpid = @csv.add_file File.basename(object.file_stream.to_s), object.label, object.usage_type, ''
      @csv.set_relation object.vpid, 'part_of',       object.parent.vpid if object.child?
    end
    @csv.set_relation object.vpid, 'manifestation', object.master.vpid if object.manifestation?
    object.manifestations.each { |obj| add_to_csv obj }
    object.children.each       { |obj| add_to_csv obj }
  end

end
