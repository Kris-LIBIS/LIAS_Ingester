# coding: utf-8

require 'ingester_module'
require 'tools/checksum'

class Initializer
  include IngesterModule
  
  def start( cfg_file )
    
    result = nil
    
    info 'Starting'
    info "Processing config file: #{cfg_file}"
    start_time = Time.now

    mtime = File.mtime(cfg_file)
    checksum = Checksum.new(:MD5).get cfg_file
    run = IngestRun.first :config_file => cfg_file, :mtime => mtime, :checksum => checksum, :order => [ :updated_at.desc ]
    
    if run.nil?
      run = IngestRun.new :created_at => Time.now
      run.init cfg_file
      run.status = Status::New
      run.save
      ApplicationStatus.instance.run = run
      info "Created new run ##{run.id}"
    elsif Status.phase(run.status) == Status::Initialize and !Status.done?(run.status)
      ApplicationStatus.instance.run = run
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
    
    info "Run ##{result} processed. Elapsed time: #{elapsed_time start_time}."
    ApplicationStatus.instance.run = nil
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
    
    ApplicationStatus.instance.run = run
    
    unless Status.phase(run.status) == Status::Initialize
      warn "Cannot undo run ##{run_id} because status is #{Status.to_string run.status}"
      return run if run.status == Status::New
      return nil
    end
    
    undo_run run
    
    info "Run ##{run_id} is reset. Elapsed time: #{elapsed_time start_time}."
    
    ApplicationStatus.instance.run = nil
    
    run
    
  end
  
  def restart( run_id )
    
    if (run = undo(run_id))
      ApplicationStatus.instance.run = run
      info "Restarting run ##{run_id}"
      process_run run
      ApplicationStatus.instance.run = nil
      info 'Done'
      return run_id
    end
    
    nil
    
  end
  
  protected
  
  def process_run( run )
    
    ApplicationStatus.instance.run = run
    
    info "Processing run ##{run.id}"
    run.status = Status::Initializing
    
    # TODO: unpack the container if necessary
    
    # get all the files
    files = get_files(run.location, run.selection, run.recursive)
    info "Found #{files.size} files to process"
    
    files.each do |f|
      obj = IngestObject.new f, run.checksum_type
      run.add_object obj
      ApplicationStatus.instance.obj = obj
      obj.status = Status::Initialized
      obj.save
      info "New object ##{obj.id} for '#{f}'"
      ApplicationStatus.instance.obj = nil
    end
    
    run.status = Status::Initialized

    info "Placed run ##{run.id} on the queue"
    
  rescue Exception => e
    unless run.nil?
      run.status = Status::InitializeFailed
    end
    print_exception e
    
  ensure
    run.save
    ApplicationStatus.instance.run = nil
    
  end
  
  def get_files( directory, match_expression, recursive )
    result = []
    file_list = Dir.glob "#{directory}/*"
    dirs, files = file_list.partition { |f| test(?d, f) }
    if match_expression
      result += files.find_all { |f| f.match match_expression }
    else
      result += files
    end
    result.sort!
    dirs.each { |d| result += get_files d, match_expression, recursive } if recursive
    result
  end
  
  def undo_run( run )
    ApplicationStatus.instance.run = run
    run.reset
    run.init run.config_file
    run.status = Status::New
    run.save
    ApplicationStatus.instance.run = nil
  end
  
end
