require 'application'
require 'tools/checksum'

class Initializer
  include ApplicationTask

  def start(cfg_file)

    result = nil

    info 'Starting'
    info "Processing config file: #{cfg_file}"

    mtime = File.mtime(cfg_file)
    checksum = Checksum.new(:MD5).get(cfg_file)
    run = IngestRun.first(:config_file => cfg_file, :mtime => mtime, :checksum => checksum, :order => [ :updated_at.desc ])
    Application.log_to(run)

    if run.nil?
      run = IngestRun.new(:created_at => Time.now)
      run.init(cfg_file)
      run.status = Status::Initializing
      run.save
      Application.log_to(run)
      info "Created new run ##{run.id}"
    elsif run.status == Status::Initializing
      info "Run exists, but did not finish, restarting previous run ##{run.id}"
      undo run
    else
      warn 'Skipping initialization of configuration file: the run already initialized'
      Application.log_end(run)
      return
    end

    # TODO: unpack the container if necessary

    # get all the files
    files = get_files(run.location, run.selection, run.recursive)
    info "Found #{files.size} files to process"
    files.each do |f|
      obj = IngestObject.new(f, run.checksum_type)
#      obj.save
      run.add_object obj
      Application.log_to(obj)
      info "New object ##{obj.id} for '#{f}'"
      Application.log_end(obj)
    end

    run.status = Status::Initialized
    run.init_end = Time.now
#    run.save

    info "Placed run ##{run.id} on the queue"
    result = run.id

  rescue Exception => e
    unless run.nil?
      run.status = Status::InitializeFailed
    end
    handle_exception e

  ensure
    unless run.nil?
      run.save
    end
    Application.log_end(run)
    info 'Done'

    result

  end

  def undo(run)
    run.ingest_objects.destroy
    run.save
  end

  private

  def get_files(directory, match_expression, recursive)
    result = []
    file_list = Dir.glob "#{directory}/*"
    file_list.each do |f|
      next unless File.exist? f
      if File.directory? f
        result += get_files(f, match_expression) if recursive
      else
        result << f if f.match(match_expression)
      end
    end
    result
  end

end
