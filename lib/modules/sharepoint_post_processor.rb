require 'modules/post_processor'

require 'tools/sharepoint_metadata_tree'
require 'tools/sharepoint_mapping'
require "tools/oracle_client"
require "tools/xml_document"

class SharepointPostProcessor < PostProcessor

  def initialize( metadata_tree_file, metadata_sql_file, mapping_file )
    @metadata_tree_file = metadata_tree_file
    @metadata_sql_file = metadata_sql_file
    @mapping_file = mapping_file
  end

  protected

  def process_config( cfg )

    unless cfg.ingest_type == :SHAREPOINT_XML
      cfg.status = Status::PostProcessed
      cfg.save
      return
    end

    start_time = Time.now
    ApplicationStatus.instance.run = cfg.ingest_run
    ApplicationStatus.instance.cfg = cfg
    info "Processing config ##{cfg.id}"

    cfg.status = Status::PostProcessing
    cfg.save

    failed_objects = []

    cfg.root_objects.each do |obj|

      next unless obj.status == Status::PostIngested

      process_object obj

      failed_objects << obj unless obj.status == Status::PostProcessed

    end # ingest_objects.all

    cfg.status = Status::PostProcessed

    cfg.save
    warn "#{failed_objects.size} objects failed during Post-Process" unless failed_objects.empty?

    # load metadata tree
    info "Reading metadata tree"
    tree = SharepointMetadataTree.open @metadata_tree_file

    # enrich the data with the pids
    info "Enriching metadata with PIDs"
    dirty = false
    tree.visit do | phase, node, _ |
      if phase == :before and metadata = node.content
        if metadata[:pid].nil? and obj = IngestObject.first(:id => metadata[:ingest_object_id])
          metadata[:pid] = obj.pid
          metadata[:ingest_status] = 'ingested'
          metadata[:ingest_id] = obj.ingest_config.ingest_id
          dirty = true
        end
      end
    end
    info "Saving metadata tree"
    tree.save @metadata_tree_file if dirty

    # export metadata to sql script
    info "Creating Scope SQL script"
    mapping = SharepointMapping.new @mapping_file
    File.open(@metadata_sql_file, 'w') do |f|
      f.puts "set define off"
      tree.visit do |phase, node, _|
        if phase == :before and metadata = node.content
          f.puts metadata.to_sql(mapping).gsub('@TABLE_NAME@','KUL_SCP_DGTL_SHP')
        end
      end
      f.puts 'quit'
    end

    info "Executing Scope SQL script"
    OracleClient.scope_client.run @metadata_sql_file

  rescue => e
    cfg.status = Status::PostProcessFailed
    handle_exception e

  ensure

    info "Config ##{cfg.id} processed. Elapsed time: #{elapsed_time(start_time)}."
    ApplicationStatus.instance.cfg = nil
    ApplicationStatus.instance.run = nil

  end

  def process_object(obj)

    ApplicationStatus.instance.obj = obj
    info "Processing object ##{obj.id}"

    obj.set_status_recursive Status::PostProcessing, Status::PostIngested
    obj.save

    update_pid_links(obj)

    obj.set_status_recursive Status::PostProcessed, Status::PostProcessing

  rescue => e
    obj.status = Status::PostProcessFailed
    handle_exception e

  ensure
    obj.save
    ApplicationStatus.instance.obj = nil

  end # process_object

  def update_pid_links( obj )
    filename = obj.file_stream
    child_pids = []
    doc = XmlDocument.open filename
    doc.xpath('//*').each do |element|
      attr = element.attribute('oid')
      next unless attr
      pid = IngestObject.first(:id => attr.content).pid
      child_pids << pid
      element.set_attribute 'pid', pid
    end
    doc.save filename
    result = DigitalEntityManager.instance.update_stream(obj.pid, filename)
    if result[:error]
      result[:error].each { |e| error "Error calling web service: #{e}"}
      error "Failed to update record file stream for object ##{obj.pid}"
      obj.status = Status::PostProcessFailed
    else
      info "Updated object links for object #{obj.pid}"
    end
    result = DigitalEntityManager.instance.add_relations(obj.pid, 'include', child_pids)
    if result[:error]
      result[:error].each { |e| error "Error calling web service: #{e}"}
      error "Failed to link child objects for object ##{obj.pid}"
      obj.status = Status::PostProcessFailed
    else
      info "Linked child objects for object #{obj.pid}"
    end
  end

end