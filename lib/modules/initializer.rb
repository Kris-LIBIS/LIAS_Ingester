require 'lib/tools/checksum'

class Initializer
  include ApplicationTask
  
  def start(cfg_file)
    
    result = nil
    
    info 'Starting'
    info "Processing config file: #{cfg_file}"
    
    mtime = File.mtime(cfg_file)
    checksum = Checksum.new(:MD5).get(cfg_file)
    run = IngestRun.first(:config_file => cfg_file, :mtime => mtime, :checksum => checksum, :order => [ :updated_at.desc ])
    
    if run.nil?
      run = IngestRun.new(:created_at => Time.now)
      run.init(cfg_file)
      run.status = Status::Initializing
      run.save
      info "Created new run ##{run.id}"
    elsif Status.phase(run.status) == Status::Initialize
      info "Run exists, but did not finish, restarting previous run ##{run.id} - status '#{Status.to_string(run.status)}'"
      undo run.id
    else
      warn 'Skipping initialization of configuration file: the run already initialized'
      Application.log_end(run)
      return run.id
    end
    
    process_run(run)
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
    info 'Done'
    
    result
    
  end
  
  def undo(run_id)
    run = IngestRun.first(:id => run_id)
    if run.nil?
      error "Could not find run ##{run_id}"
      return nil
    end
    unless Status.phase(run.status) == Status::Initialize or run.status == Status::New
      warn "Cannot undo run ##{run_id} initialization because status is #{Status.to_string(run.status)}"
      return nil
    end
    run.ingest_objects.destroy
    run.save
    info "Run ##{run_id} is reset"
    run
  end
  
  def restart(run_id)
    
    result = nil
    
    info 'Restarting run ##{run_id}'
    
    if run = undo(run_id)
      process_run run
      result = run_id
    end
    
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
  
  private
  
  def process_run(run)
    
    Application.log_to run
    
    info "Processing run ##{run.id}"
    
    # TODO: unpack the container if necessary
    
    # get all the files
    files = get_files(run.location, run.selection, run.recursive)
    info "Found #{files.size} files to process"
    
    files.each do |f|
      obj = IngestObject.new(f, run.checksum_type)
      run.add_object obj
      Application.log_to(obj)
      info "New object ##{obj.id} for '#{f}'"
      Application.log_end(obj)
    end
    
    run.status = Status::Initialized
    run.init_end = Time.now
    
    info "Placed run ##{run.id} on the queue"
    
  rescue Exception => e
    unless run.nil?
      run.status = Status::InitializeFailed
    end
    handle_exception e
    
  ensure
    Application.log_end run
    
  end
  
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
