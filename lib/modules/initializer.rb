require 'lib/application_task'
require 'lib/tools/checksum'

class Initializer
  include ApplicationTask
  
  def start( cfg_file )
    
    result = nil
    
    info 'Starting'
    info "Processing config file: #{cfg_file}"
    
    mtime = File.mtime(cfg_file)
    checksum = Checksum.new(:MD5).get cfg_file
    run = IngestRun.first :config_file => cfg_file, :mtime => mtime, :checksum => checksum, :order => [ :updated_at.desc ]
    
    if run.nil?
      run = IngestRun.new :created_at => Time.now
      run.init cfg_file
      run.status = Status::New
      run.save
      Application.log_to run
      info "Created new run ##{run.id}"
    elsif Status.phase(run.status) == Status::Initialize and !Status.done?(run.status)
      Application.log_to run
      info "Run exists, but did not finish, restarting previous run ##{run.id} - status '#{Status.to_string run.status}'"
      undo run.id
      run.init cfg_file
    else
      warn 'Skipping initialization of configuration file: the run already initialized'
      return run.id
    end
    
    process_run run
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
    
    Application.log_end run
    info 'Done'
    
    result
    
  end
  
  def undo( run_id )
    
    start_time = Time.now
    
    run = IngestRun.first :id => run_id
    
    if run.nil?
      error "Could not find run ##{run_id}"
      return nil
    end
    
    Application.log_to run
    
    unless Status.phase(run.status) == Status::Initialize
      warn "Cannot undo run ##{run_id} because status is #{Status.to_string run.status}"
      return run if run.status == Status::New
      return nil
    end
    
    undo_run run
    
    info "Run ##{run_id} is reset. Elapsed time: #{elapsed_time start_time}."
    
    Application.log_end run
    
    run
    
  end
  
  def restart( run_id )
    
    if run = undo(run_id)
      Application.log_to run
      info "Restarting run ##{run_id}"
      process_run run
      Application.log_end run
      info 'Done'
      return run_id
    end
    
    nil
    
  end
  
  private
  
  def process_run( run )
    
    start_time = Time.now
    Application.log_to run
    
    info "Processing run ##{run.id}"
    run.status = Status::Initializing
    
    # TODO: unpack the container if necessary
    
    # get all the files
    files = get_files run.location, run.selection, run.recursive
    info "Found #{files.size} files to process"
    
    files.each do |f|
      obj = IngestObject.new f, run.checksum_type
      run.add_object obj
      Application.log_to obj
      obj.status = Status::Initialized
      obj.save
      info "New object ##{obj.id} for '#{f}'"
      Application.log_end obj
    end
    
    run.status = Status::Initialized
    run.init_end = Time.now
    
    info "Placed run ##{run.id} on the queue"
    
  rescue Exception => e
    unless run.nil?
      run.status = Status::InitializeFailed
    end
    print_exception e
    
  ensure
    run.save
    info "Run ##{run.id} processed. Elapsed time: #{elapsed_time start_time}."
    Application.log_end run
    
  end
  
  def get_files( directory, match_expression, recursive )
    result = []
    file_list = Dir.glob "#{directory}/*"
    file_list.each do |f|
      next unless File.exist? f
      if File.directory? f
        result += get_files f, match_expression, recursive if recursive
      else
        result << f if f.match match_expression
      end
    end
    result
  end
  
  def undo_run( run )
    run.reset
    run.init run.config_file
    run.status = Status::New
    run.save
  end
  
  def undo_config( cfg )
    debug "Destroying config ##{cfg.id}."
    cfg.destroy
  end
  
  def undo_object( obj )
    debug "Deleting object ##{obj.id}."
    obj.delete
  end
  
end
