require 'modules/post_processor'

require 'tools/sharepoint_metadata_tree'
require 'tools/sharepoint_mapping'
require "tools/oracle_client"

class SharepointPostProcessor < PostProcessor

  def initialize( metadata_tree_file, metadata_sql_file, mapping_file )
    @metadata_tree_file = metadata_tree_file
    @metadata_sql_file = metadata_sql_file
    @mapping_file = mapping_file
  end

  protected

  def process_config( cfg )

    return unless cfg.ingest_type == :SHAREPOINT_XML

    start_time = Time.now
    ApplicationStatus.instance.run = cfg.ingest_run
    ApplicationStatus.instance.cfg = cfg
    info "Processing config ##{cfg.id}"

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

    info "Config ##{cfg.id} processed. Elapsed time: #{elapsed_time(start_time)}."
    ApplicationStatus.instance.cfg = nil
    ApplicationStatus.instance.run = nil

  end

end