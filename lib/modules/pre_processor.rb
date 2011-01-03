require 'application'
require 'modules/file_checker'
require 'tools/complex_file_collecter'

class PreProcessor
  include ApplicationTask

  public

  def start
    info 'Starting'

      run_queue = IngestRun.all(:status => Status::Initialized)

      run_queue.each do |run|
        process_run run
      end # run_queue.each

    rescue Exception => e
      handle_exception e
    
    ensure
      info 'Done'

  end

  def process_run( run )

    Application.log_to(run)

    info "Processing run ##{run.id}"
    run.status = Status::PreProcessing

    # for each configuration
    run.ingest_configs.each do |config|
      process_config config
    end # ingest_configs.each
    unless run.ingest_objects.empty?
      warn "#{run.ingest_objects.size} Objects remain unprocessed in run ##{run.id}"
    end
    run.status = Status::PreProcessed

  rescue Exception => e
    run.status = Status::PreProcessFailed
    handle_exception e

  ensure
    run.save
    Application.log_end(run)

  end

  private

  def process_config( config )

    Application.log_to(config)
    config.status = Status::PreProcessing

    @checker = FileChecker.new config
    @collecter = nil
    @collecter = ComplexFileCollecter.new(config) if config.complex

    info "Processing config ##{config.id}"
    collected_objects = config.ingest_run.ingest_objects
    collected_objects.each do |object|
      process_object object, config
    end
    config.save
    if config.get_objects.empty?
      config.status = Status::Idle
      warn "Config ##{config.id} did not match any objects"
    else
      # all files that matched the config criteria are now part of the config
      # these files should be removed from the run
      config.ingest_run.ingest_objects -= config.ingest_objects
      config.status = Status::PreProcessed if config.check_object_status(Status::PreProcessed)
      info "Placed config ##{config.id} on the queue."
    end

  rescue Exception => e
    config.status = Status::PreProcessFailed
    handle_exception e

  ensure
    Application.log_end(config)
#    config.ingest_run.save

  end

  def process_object( object, config )

    Application.log_to(object)

    info "Processing object ##{object.id}: '#{object.file_path}'"
    object.status = Status::PreProcessing

    if not(@checker.match(object))
      object.status = Status::New
      object.message = nil
      debug "Object ##{object.id} did not match"
    elsif not(@checker.check(object))
      error "Object ##{object.id} failed tests: '#{object.message}'"
      object.status = Status::PreProcessFailed
    else
#      info "Object ##{object.id} passed tests"
      config.add_object(object)
#      info "Object ##{object.id} added"
      object.status = Status::PreProcessed
#      info "Object ##{object.id} updated status"
      unless @collecter.nil? or @collecter.check(object)
        error "Object ##{object.id} failed building complex object"
        object.status = Status::PreProcessFailed
      end

    end

#    object.get_run.save
#    info "Object ##{object.id} saved in the database"

  rescue Exception => e
    object.status = Status::PreProcessFailed
    handle_exception e

  ensure
#    object.save
    info "Object ##{object.id} preprocessed"
    Application.log_end(object)

  end

end
