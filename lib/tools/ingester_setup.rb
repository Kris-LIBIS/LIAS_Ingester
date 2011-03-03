require 'csv'
require_relative 'xml_writer'

class IngesterSetup
  include XmlWriter
  
  LABELMAPPING = {
    :vpid               => 'vpid',
    :file_name          => 'stream_ref/file_name',
    :relation_type      => 'relations/relation/type',
    :related_to         => 'relations/relation/vpid',
    :usage_type         => 'control/usage_type',
    :preservation_level => 'control/preservation_level',
    :entity_type        => 'control/entity_type',
    :label              => 'control/label'
    }
  
  attr_reader :requires_mets
  
  attr_reader :tasks
  
  TaskParamOrder = {
    'MetadataInserter' =>     [ :Link, :Mddesc, :Mdfilename, :Mid, :ComplexOnly, :Extension, :Size ],
    'AttributeAssignment' =>  [ :Name1, :Value1, :Name2, :Value2, :Name3, :Value3, :apply_to_parent_only, :extension],
    'FullText' =>             [ :Encoding, :Extension ]
  }
  
  def initialize
    @last_id = 0
    @files = Hash.new
    @is_complex = false
    @requires_mets = false
    @tasks = Array.new
  end
  
  def add_metadata( options = {} )
    task              = Hash.new
    task[:task_name]  = 'MetadataInserter'
    task[:name]       = 'Add Metadata'
    params            = Hash.new
    task[:params]     = params
    params[:Link]         = ''
    params[:Mddesc]       = ''
    params[:Mdfilename]   = ''
    params[:Mid]          = ''
    params[:ComplexOnly]  = 'false'
    params[:Extension]    = ''
    params[:Size]         = ''
    options.each do |k,v|
      params[k] = v if [:Link, :Mddesc, :Mdfilename, :Mid, :ComplexOnly, :Extension, :Size].include? k
    end
    @tasks << task
  end
  
  def add_acl( id, options = {} )
    add_metadata( {:Mddesc => 'accessrights rights_md',
                   :Link => 'true',
                   :Mid => id.to_s
                   }.merge!(options) )
  end
  
  def add_dc( file_name, options = {} )
    add_metadata( {:Mddesc => 'descriptive dc',
                   :Link => 'true',
                   :Mdfilename => file_name
                   }.merge!(options) )
  end
  
  def add_control_fields( name_values, extension, options = {} )
    
    return unless name_values
    
    keys = name_values.keys
    until keys.empty?
      task              = Hash.new
      task[:task_name]  = 'AttributeAssignment'
      task[:name]       = 'Control section Attribute Assignment'
      params            = Hash.new
      task[:params]     = params
      params[:Name1]    = ''
      params[:Value1]   = ''
      params[:Name2]    = ''
      params[:Value2]   = ''
      params[:Name3]    = ''
      params[:Value3]   = ''
      1.upto(3) do |n|
        key = keys.shift
        params["Name#{n}".to_sym] = key
        params["Value#{n}".to_sym] = name_values[key]
      end
      params[:apply_to_parent_only] = 'false'
      params[:extension]  = extension
      options.each do |k,v|
        params[k] = v if [:apply_to_parent_only, :extension].include? k
      end
      @tasks << task
    end
    
  end
  
  def full_text_extraction( options = {} )
    task              = Hash.new
    task[:task_name]  = 'FullText'
    task[:name]       = 'Full Text Extraction'
    params            = Hash.new
    task[:params]     = params
    params[:Encoding]   = 'UTF-8'
    params[:Extension]  = 'ftx'
    options.each { |k,v| params[k] = v if [:Encoding, :Extension].include? k }
    @tasks << task
  end
  
  def add_complex_object( name, usage_type )
    @is_complex ||= true
    add_file name, usage_type, 'COMPLEX'
  end
  
  def add_dir( name )
    add_file name, 'VIEW', 'directory'
  end
  
  def add_file( label, usage_type, entity_type = nil, obj = nil )
    file_info = Hash.new
    @last_id += 1
    file_info[:vpid] = @last_id
    file_info[:file_name] = obj.relative_stream.to_s if obj and obj.file_stream
#    file_info[:file_name] = obj.flattened_path if obj and obj.file_stream
    file_info[:label] = label
    case usage_type.upcase
    when /^(COMPLEX_)?ORIGINAL$/
      file_info[:usage_type] = 'ARCHIVE'
      file_info[:preservation_level] = 'critical'
    when /^((\d+|COMPLEX)_)?ARCHIVE$/
      file_info[:usage_type] = 'ARCHIVE'
      file_info[:preservation_level] = 'high'
    when /^((\d+|COMPLEX)_)?VIEW_MAIN$/
      file_info[:usage_type] = 'VIEW_MAIN'
      file_info[:preservation_level] = 'any'
    when /^((\d+|COMPLEX)_)?VIEW$/
      file_info[:usage_type] = 'VIEW'
      file_info[:preservation_level] = 'any'
    when /^((\d+|COMPLEX)_)?THUMBNAIL$/
      file_info[:usage_type] = 'THUMBNAIL'
      file_info[:preservation_level] = 'any'
    else
      file_info[:preservation_level] = 'any'
    end
    file_info[:entity_type] = entity_type
    file_info[:object] = obj
    @files[@last_id] = file_info
    return @last_id
  end
  
  def set_relation( vpid, relation_type, to_vpid )
    vpid = vpid.to_i
    relation_type = relation_type.to_sym
    to_vpid = to_vpid.to_i
    return false if ( vpid < 1 or vpid > @last_id )
    return false if ( to_vpid < 1 or to_vpid >= vpid )
    @files[vpid][:relation_type] = relation_type
    @files[vpid][:related_to] = to_vpid
    @requires_mets ||= ( relation_type == :part_of and @files[to_vpid][:relation_type] == :part_of )
    return true
  end
  
  def finalize_setup( setup_dir )
    # write ingest_settings
    write_settings setup_dir + '/ingest_settings.xml'
    
    # write csv/mets file
    if @requires_mets
      write_mets "#{setup_dir}/transform/mets.xml"
    else
      write_csv "#{setup_dir}/transform/values.csv"
      write_mapping "#{setup_dir}/transform/mapping.xml"
    end
  end
  
  def get_related( relation, to_vpid, usage_type = nil )
    relation = relation.to_sym
    to_vpid = to_vpid.to_i
    result = @files.find_all do |vpid, f|
      f[:relation_type] == relation and f[:related_to] == to_vpid and
      ( usage_type ? f[:usage_type] == usage_type : true ) 
    end
  end
  
  def write_settings( file )
    doc = create_document
    
    root = create_node 'ingest_settings', :namespaces => {
      :node_ns => 'xb',
      'xb' => 'http://com/exlibris/digitool/common/jobs/xmlbeans' }
    doc.root = root
    
    node = nil
    
    if @requires_mets
      node = create_node 'transformer_task', :attributes => {
        'name'        => 'METS xml file and associated file stream(s)',
        'class_name'  => 'com.exlibris.digitool.ingest.transformer.metsbased.MetsBasedTransformer' }
      node << ( create_node 'param', :attributes => { 'name'   =>  'mets_file', 'value'  =>  'mets.xml' } )
      node << ( create_node 'param', :attributes => { 'name'   =>  'downloadFiles', 'value'  =>  'false' } )
    else
      node = create_node 'transformer_task', :attributes => {
        'name'        => 'Comma separated value (.csv) file',
        'class_name'  => 'com.exlibris.digitool.ingest.transformer.valuebased.CsvTransformer' }
      node << ( create_node 'param', :attributes => { 'name'   => 'template_file', 'value'  => 'values.csv' } )
      node << ( create_node 'param', :attributes => { 'name'   => 'mapping_file', 'value'  => 'mapping.xml' } )
    end
    
    root << node
    
    i = 0
    chain = create_node 'tasks_chain', :attributes => { 'name' => 'Task Chain' }
    
    @tasks.each do |task|
      chain << ( write_task task, i )
      i += 1
    end
    
    ( root << chain ) if i > 0
    
    root << ( create_node 'ingest_task', :attributes => { 'name' => 'LIAS_ingester' } )
    
    save_document doc, file
    
  end

  def write_task( task, nr )
    
    node = create_node 'task_settings', :attributes => {
      'id'        => nr.to_s,
      'task_name' => task[:task_name],
      'name'      => task[:name] }
    
    TaskParamOrder[task[:task_name]].each do |p|
      param = task[:params][p]
      node << ( create_node 'param', :attributes => { 'name' => p.to_s, 'value' => param.to_s } )
    end
    
    return node
    
  end

  def write_csv( file )
    ### NOTE: This is a workaround for what is probably a bug in DigiTool: in complex object ingests,
    ######### the VIEW_MAIN manifestations are not displayed by the viewer (could this be an issue in
    ######### the on-the-fly METS creator in the delevery module?)
    @files.each { |vpid, f| f[:usage_type] = 'VIEW' if f[:usage_type] == 'VIEW_MAIN' } if @is_complex
    
    CSV.open( file, 'w') do |csv|
      csv << LABELMAPPING.keys
      @files.each do |vpid,file_info|
        row = Array.new
        LABELMAPPING.keys.each do |tag|
          element = file_info[tag] ? file_info[tag].to_s : ''
          row << element
        end
        csv << row
      end
    end
  end
  
  def create_mapping( position, target )
    x_map = create_node 'x_map'
    x_map << create_node('x_source', :attributes => { 'position' => position } )
    x_map << create_text_node( 'x_target', target)
    return x_map
  end
  
  def write_mapping( file )
    doc = create_document
    
    root = create_node('x_mapping', :attributes => { 'start_from_line' => '2' }, :namespaces => {
      :node_ns  =>  'tm',
      'tm'      =>  'http://com/exlibris/digitool/repository/transMap/xmlbeans' } )
    
    doc.root = root
    
    stream_map = create_node 'x_map'
    stream_map << ( create_text_node 'x_target', 'stream_ref' )
    stream_map << ( create_text_node 'x_attr',   'store_command' )
    stream_map << ( create_text_node 'x_default','copy' )
    
    root << stream_map
    
    stream_map = create_node 'x_map'
    stream_map << ( create_text_node 'x_target', 'stream_ref/directory_path' )
    stream_map << ( create_text_node 'x_default','default' )
    
    root << stream_map
    
    LABELMAPPING.each_with_index do |mapping,i|
      root << ( create_mapping((i+1).to_s, mapping[1]) )
    end
    
    root << ( create_mapping '4','stream_ref/file_id' )
    
    save_document doc, file
    
  end
  
  def write_mets( target_file )
    
    @ns = 'mets:'
    doc       = create_document
    doc.root  = create_node @ns + 'mets'
    add_namespaces doc.root, 'mods'   => 'http://www.loc.gov/mods/v3'
    add_namespaces doc.root, 'mets'   => 'http://www.loc.gov/METS/'
    add_namespaces doc.root, 'xsi'    => 'http://www.w3.org/2001/XMLSchema-instance'
    add_namespaces doc.root, 'xlink'  => 'http://www.w3.org/1999/xlink'
    add_namespaces doc.root, 'rts'    => 'http://cosimo.stanford.edu/sdr/metsrights/'
    add_namespaces doc.root, 'mix'    => 'http://www.loc.gov/mix/'
    add_attributes doc.root, 'xsi:schemaLocation' => 'http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/mods/v3 .http://www.loc.gov/mods/v3/mods-3-1.xsd http://www.loc.gov/mix/ http://www.loc.gov/mix/mix.xsd http://cosimo.stanford.edu/sdr/metsrights/ http://cosimo.stanford.edu/sdr/metsrights.xsd'
    add_attributes doc.root, 'xmlns' => 'http://www.loc.gov/METS/' if @ns == ''
    
    doc.root  << ( header       = create_node @ns + 'metsHdr',      :attributes => { 'ID' => 'hdr' } )
    doc.root  << ( filesec      = create_node @ns + 'fileSec',      :attributes => { 'ID' => 'fsec' } )
    filesec   << ( archives     = create_node @ns + 'fileGrp',      :attributes => { 'ID' => 'fgrp_1', 'USE' => 'archive' } )
    filesec   << ( thumbnails   = create_node @ns + 'fileGrp',      :attributes => { 'ID' => 'fgrp_2', 'USE' => 'thumbnail' } )
    filesec   << ( views        = create_node @ns + 'fileGrp',      :attributes => { 'ID' => 'fgrp_3', 'USE' => 'reference' } )
    filesec   << ( view_mains   = create_node @ns + 'fileGrp',      :attributes => { 'ID' => 'fgrp_4', 'USE' => 'reference' } )
    doc.root  << ( logical_map  = create_node @ns + 'structMap',    :attributes => { 'ID' => 'smap_1', 'TYPE' => 'LOGICAL',  'LABEL' => 'Inhoud' } )
    
    root_objects = @files.find_all do |vpid,file_info|
      file_info[:relation_type].nil?
    end
    
    if root_objects.size != 1
      @@logger.error(self.class) { "METS ingest can only process with exaclty one root object" }
      return
    end
    
    root_object = root_objects.first
    root_label = root_object[1][:label]
    add_attributes doc.root, 'LABEL' => root_label
    
    add_node_recursive root_object[1], logical_map
    
    @files.each do |vpid,file_info|
      next unless obj = file_info[:object]
      next unless file_info[:file_name]
      file = create_node @ns + 'file', :attributes => { 'ID' => "file_#{vpid.to_s}" }
      if obj.file_info
        add_attributes(file,
                       'MIMETYPE' => obj.mime_type,
                       'SIZE' => File.size(obj.file_path).to_s,
                       'CHECKSUM' => obj.file_info.get_checksum(:MD5))
      end
      group_id = file_info[:relation_type] == :manifestation ? file_info[:related_to] : file_info[:vpid]
      add_attributes file, 'GROUPID' => "group_#{group_id}"
      file << ( file_location = create_node @ns + 'FLocat' )
      add_attributes file_location, 'LOCTYPE' => 'URL'
      add_attributes file_location, 'xlink:href' => "file://streams/#{obj.relative_stream.to_s}"
      case file_info[:usage_type]
      when 'ARCHIVE'
        archives << file
      when 'VIEW'
        views << file
      when 'VIEW_MAIN'
        view_mains << file
      when 'THUMBNAIL'
        thumbnails << file
      end
    end
    
    save_document doc, target_file
    
  end
  
  def add_node( file, parent_node )
    
    # First create the div node
    div_node = add_div_node file, parent_node
    
    f = get_related( :manifestation, file[:vpid], 'VIEW_MAIN' ).first
    add_fptr_node f[1], div_node if f
    
    return div_node
    
  end
  
  def add_div_node( file, parent_node )
    # create ID for the node
    ## Actually, the IDs on all structMap elements are reset to random numbers by the DTL ingester
    parent_id = parent_node['ID']
    parent_id.gsub!(/^div_/, '') if parent_id
    this_id = "div_#{parent_id}_#{file[:vpid].to_s}"
    
    # create the div node
    this_node = create_node @ns + 'div', :attributes => { 'ID' => this_id, 'LABEL' => File.basename(file[:label]) }
    
    parent_node << this_node
    
    return this_node
  end
  
  def add_fptr_node( file, parent_node )
    
    # add a fptr node if there is a physical file
    if file[:file_name]
      parent_node << ( create_node @ns + 'fptr', :attributes => {
        'FILEID' => "file_#{file[:vpid].to_s}", 'ID' => "fptr_#{parent_node['ID']}_#{file[:vpid].to_s}" } )
    end

  end 
  
  def add_node_recursive( file, parent_node )
    
    this_node = add_node file, parent_node
    
    get_related( :part_of, file[:vpid] ).each { |vpid, f| add_node_recursive f, this_node unless f[:object] and f[:object].leaf? }
    
    get_related( :part_of, file[:vpid] ).each { |vpid, f| add_node_recursive f, this_node if f[:object] and f[:object].leaf? }
    
  end
  
end
