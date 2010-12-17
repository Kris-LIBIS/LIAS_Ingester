require 'csv'
require 'tools/xml_writer'

class IngesterSetup
  include XmlWriter

  LabelMapping = {
    'vpid'                => 'vpid',
    'file_name'           => 'stream_ref/file_name',
    'relation_type'       => 'relations/relation/type',
    'related_to'          => 'relations/relation/vpid',
    'usage_type'          => 'control/usage_type',
    'preservation_level'  => 'control/preservation_level',
    'entity_type'         => 'control/entity_type',
    'label'               => 'control/label'
  }

  attr_reader :next_id
  attr_reader :header
  attr_reader :files
  
  def initialize
    @next_id = 0
    @header = FixedHeader
    @files = Hash.new
  end

  def add_complex_object( name, usage_type = 'VIEW' )
    add_file '', name, usage_type, 'COMPLEX'
  end

  def add_dir( name )
    add_file '', name, 'VIEW', 'directory'
  end

  def add_file( file_name, label, usage_type, entity_type = nil, obj = nil )
    file_info = Hash.new
    file_info[:file_name] = file_name
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
    @files[@next_id] = file_info
    @next_id += 1
    return @next_id - 1
  end

  def set_relation( vpid, relation_type, to_vpid )
    vpid = vpid.to_i
    to_vpid = to_vpid.to_i
    return false if ( vpid < 0 or vpid >= @next_id )
    return false if ( to_vpid < 0 or to_vpid >= vpid )
    @files[vpid][:relation_type] = relation_type
    @files[vpid][:related_to] = to_vpid
    return true
  end

  def write_csv( file )
    CSV.open( file, 'w') do |csv|
      csv << @header
      0.upto(@next_id-1) do |n|
        file_info = @files[n]
        row = Array.new
        row << n
        FixedHeader[1..-1].each do |tag|
          element = file_info[tag.to_sym] ? file_info[tag.to_sym] : ''
          row << element
        end
        csv << row
      end
    end
  end

  def write_mets( file )
    @document       = create_document
    @document.root  = create_node('mets:mets')
    add_namespaces(@document.root, 'mets'   => 'http://www.loc.gov/METS/')
    add_namespaces(@document.root, 'mods'   => 'http://www.loc.gov/mods/v3')
    add_namespaces(@document.root, 'rts'    => 'http://cosimo.stanford.edu/sdr/metsrights/')
    add_namespaces(@document.root, 'mix'    => 'http://www.loc.gov/mix/')
    add_namespaces(@document.root, 'xlink'  => 'http://www.w3.org/1999/xlink')
    add_namespaces(@document.root, 'xsi'    => 'http://www.w3.org/2001/XMLSchema-instance')
    add_attributes(@document.root, 'xsi:schemaLocation' => 'http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/mods/v3 .http://www.loc.gov/mods/v3/mods-3-1.xsd http://www.loc.gov/mix/ http://www.loc.gov/mix/mix.xsd http://cosimo.stanford.edu/sdr/metsrights/ http://cosimo.stanford.edu/sdr/metsrights.xsd')

    archives   = create_node('mets:fileGrp', :attributes => {'USE' => 'archive'})
    thumbnails = create_node('mets:fileGrp', :attributes => {'USE' => 'thumbnail'})
    references = create_node('mets:fileGrp', :attributes => {'USE' => 'reference'})

    @files.each do |n,file_info|
      file = create_node('mets:file')
      add_attributes(file, 'ID' => "file_#{n}")
      if obj = file_info[:object]
        add_attributes(file, 'MIMETYPE' => obj.mime_type) if obj.mime_type
        add_attributes(file, 'SIZE' => File.size(obj.file_path)) if obj.file_path
        add_attributes(file, 'CREATED' => obj.file_info.created_at.
      add_attributes(file, '' => )
      add_attributes(file, '' => )
      case file_info[:relation_type]
      when nil
      when 'part_of'
      when 'manifestation'
        
    end

    @document.root  << (@header     = create_node('mets:metsHdr'))
    @document.root  << (@dmdsec     = create_node('mets:dmdSec'))
    @document.root  << (@amdsec     = create_node('mets:amdSec'))
    @document.root  << (@filesec    = create_node('mets:fileSec'))
    @filesec        << (@archives   = create_node('mets:fileGrp', :attributes => {'USE' => 'archive'}))
    @document.root  << (@s_map      = create_node('mets:structMap'))
    @document.root  << (@slink      = create_node('mets:structLink'))
    @document.root  << (@behavior   = create_node('mets:behaviorSec'))
    

end
