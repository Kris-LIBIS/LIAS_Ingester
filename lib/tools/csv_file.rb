require 'csv'
require_relative 'xml_writer'

class CsvFile
  include XmlWriter

  FixedHeader  = ['vpid', 'file_name', 'relation_type', 'related_to', 'usage_type', 'preservation_level', 'entity_type', 'label']
  FixedMapping = ['vpid', 'stream_ref/file_name', 'relations/relation/type', 'relations/relation/vpid', 'control/usage_type', 'control/preservation_level', 'control/entity_type', 'control/label']
#  FixedOptions = [:file_name, :usage_type, :preservation_level, :entity_type, :label]

  attr_reader :next_id
  attr_reader :header
  attr_reader :files
#  attr_reader :extra_header
#  attr_reader :extra_mapping

  def initialize
    @next_id = 0
    @header = FixedHeader
    @files = Hash.new
  end

  def add_complex_object( name, usage_type )
    add_file '', name, usage_type, 'COMPLEX'
  end

  def add_file( file_name, label, usage_type, entity_type = nil, extra_options = {} )
    file_info = Hash.new
    file_info[:file_name] = file_name
    file_info[:label] = label
    case usage_type.upcase
    when /ORIGINAL$/
      file_info[:usage_type] = 'ARCHIVE'
      file_info[:preservation_level] = 'critical'
    when /ARCHIVE$/
      file_info[:usage_type] = 'ARCHIVE'
      file_info[:preservation_level] = 'high'
    when /VIEW_MAIN$/
      file_info[:usage_type] = 'VIEW_MAIN'
      file_info[:preservation_level] = 'any'
    when /VIEW$/
      file_info[:usage_type] = 'VIEW'
      file_info[:preservation_level] = 'any'
    when /THUMBNAIL$/
      file_info[:usage_type] = 'THUMBNAIL'
      file_info[:preservation_level] = 'any'
    else
      Application.warn('CsvFile') {"Unknown usage type: '#{usage_type}'"}
      file_info[:preservation_level] = 'any'
    end
    file_info[:entity_type] = entity_type
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

  def write( file )
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

  def create_mapping( position, target )
    x_map = create_node 'x_map'
    x_map << create_node('x_source',
                         :attributes => { 'position' => position })
    x_map << create_text_node( 'x_target', target)
    return x_map
  end

  def write_mapping( file )
    doc = create_document
    
    root = create_node('x_mapping',
                       :namespaces => { :node_ns  =>  'tm',
                                        'tm'      =>  'http://com/exlibris/digitool/repository/transMap/xmlbeans'
                                      },
                       :attributes => { 'start_from_line' => '2' }
                      )
    
    doc.root = root
    
    stream_map = create_node 'x_map'
    stream_map << create_text_node('x_target', 'stream_ref')
    stream_map << create_text_node('x_attr',   'store_command')
    stream_map << create_text_node('x_default','copy')
    
    root << stream_map
    
    stream_map = create_node 'x_map'
    stream_map << create_text_node('x_target', 'stream_ref/directory_path')
    stream_map << create_text_node('x_default','default')
    
    root << stream_map
    
    0.upto(FixedHeader.size - 1) do |n|
      root << create_mapping( (n+1).to_s, FixedMapping[n] )
    end
    
    root << create_mapping('4','stream_ref/file_id')
    
    save_document doc, file
    
  end

end
