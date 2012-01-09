# coding: utf-8

require 'tree'
require 'highline'
require 'uri'
require 'net/http'
require 'net/https'
require 'fileutils'

require 'awesome_print'

require 'ingester_task'
require 'libis/record/sharepoint_record'
#require 'tools/xml_document'

class SharepointMetadataTree
  include IngesterTask
  
  attr_reader :root_node
  
  def initialize( root_node = nil )
    @root_node = root_node || Tree::TreeNode.new('')
  end

  def search
    return @search if @search
    @search = SharepointSearch.new
  end
  
  def add( metadata )
    node = get(metadata.relative_path)
    return nil unless node
#    metadata[:node] = node
    node.content = metadata
    node
  end
  
  def get( path )
	return nil unless path
    node = @root_node
    path.to_s.split('/').each do |p|
      new_node = node[p]
      unless new_node
        new_node = Tree::TreeNode.new(p)
        node << new_node
      end
      node = new_node
    end
    node
  end
  
  def []( path )
    node = @root_node
    path.to_s.split('/').each do |p|
      node = node[p]
      return nil unless node
    end
    node
  end

  def at_index( index )
    found = nil
    @root_node.each do |node|
      if node.has_content? and node.content[:index].to_i == index.to_i
        found = node
      end
    end
    found
  end
  
  def file_path( to_node, from_node )
    
    return nil unless to_node
    
    # from root => simple join
    unless from_node
      path = to_node.parentage.tap {|o| o.pop }.reverse << to_node
      path = path.collect {|o| o.name}
      return path.join('/')
    end
    
    # special case: from_node is current node
    return "#{to_node.name}" if from_node == to_node
    
    # from_node should not be a file object
    from_node = from_node.parent if from_node && from_node.content && from_node.content.is_file?
    
    # the path from root to the current node
    tgt_path = to_node.parentage.reverse << to_node
    
    # from_node is parent of current node => we cut the tgt_path from the from_node
    if i = tgt_path.find_index { |node| from_node == node }
      return tgt_path.drop(i+1).collect{|o| o.name }.join('/')
    end
    
    # strip common part from src and tgt path
    #noinspection RubyResolve
    src_path = from_node.parentage.reverse
    src_path << from_node unless from_node.content && from_node.content.is_file?
    src_path = src_path.drop_while do |p|
      result = false
      if p == tgt_path.first
		tgt_path.shift
		result = true
      end
      result
    end
    
    # up path
    result = '../' * src_path.size
    
    # add down path
    result + tgt_path.collect{|o|o.name}.join('/')
  
  end
  
  def each( &block )
    @root_node.each(&block)
  end
  
  def collect_metadata( mapping, selection )
    tags_not_found = Set.new
    count = 0
    info 'Collecting metadata'
    search.query '0', 'ID', 'Te verwerken documenten', value_type: 'Number', query_operator: '>', limit: 1000, selection: selection
    search.each do |record|

      next unless selection.nil? or selection.empty? or
          record.relative_path =~ /^#{selection}$/ or
          record.relative_path =~ /^#{selection}\//

      tags_not_found += record.keys - mapping.keys

      debug "metadata: '#{record.inspect}''"

      count += 1
      record[:index] = count

      add record
      info "Collected #{count} records so far ..." if count % 100 == 0

    end

    info '%6d Records found.' % count

    tags_not_found.each do |tag|
      warn "Label '#{tag}' not found in the mapping table."
    end

  end

  def download_files( selection, download_dir )

    FileUtils.mkpath download_dir

    visit( self[selection]) do | phase, node, _ |

      metadata = node.content

      next unless phase == :before and metadata

      next unless metadata.is_file? and metadata.url

      file_path = File.join( download_dir, metadata.relative_path )
      path = File.dirname file_path

      next if File.exist? file_path

      FileUtils.mkpath path

      file_size = metadata.file_size

      http_to_file file_path, metadata.url, username: search.username, password: search.password, ssl: true, file_size: file_size

    end

  end
  
  def visit( tree_node = @root_node, options = {}, &block )
      yield :before, tree_node, options
      visit_children tree_node, options, &block
      yield :after, tree_node, options
  end

  def visit_children( tree_node = @root_node, options = {}, &block )
    tree_node.children.each do |child|
      my_options = options.dup
      yield :before, child, my_options
      visit_children child, my_options, &block
      yield :after, child, my_options
    end
  end

  def save( file )
    xml_doc = XmlDocument.new
    xml_doc.root = xml_doc.create_node 'records'
    visit do | phase, node, _ |
      if phase == :before and node.has_content?
        #noinspection RubyResolve
        xml_doc.root << node.content.to_xml.root
      end
    end
    xml_doc.save file
  end

  def self.open( file )
    tree = SharepointMetadataTree.new
    xml_doc = XmlDocument.open file
    xml_doc.root.element_children.each do | record |
      tree.add SharepointRecord.from_xml record
    end
    tree
  end

  def print( file_name )
    File.open(file_name,'w:utf-8') do |f|
      visit( root_node, prefix: '', in_map: false ) do |phase, node, options|
        if phase == :before
          node_string = ' ' * 11
          prefix = ' ' * 2
          prefix = '-' * 2 if options[:in_map]
          if metadata = node.content
            code = metadata.content_code
            code += '*' if metadata.is_described?
            if code == 'M'
              options[:in_map] = true
              prefix = '|-'
            end
            node_string = sprintf '%-2s %6d - ', code, metadata[:index].to_i
          end
          node_string += sprintf "%s%-130s", options[:prefix], node.name
          node_string += ' [' + metadata.content_type + ']' if metadata
          f.puts node_string
          options[:prefix] += prefix
        end
      end
    end
    File.expand_path file_name
  end

  def print_metadata( file_name, mapping )
    File.open(file_name,'w:utf-8') do |f|
      visit { |phase, node, _| node.content.print_metadata(f, mapping) if (phase == :before and node.content) }
    end
    File.expand_path file_name
  end

  protected
  
  # Based on http://stackoverflow.com/questions/2263540/how-do-i-download-a-binary-file-over-http-using-ruby
  def http_to_file(filename, url, opt={})
    debug "Downloading: '#{url}' -> '#{filename}'"
    opt = { :ssl => false }.merge(opt)
    File.open(filename, 'wb') { |f|
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = opt[:ssl]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(opt[:username], opt[:password])
      received_size = 0
      http.request(request) { |response|
        f << response.body
        received_size = f.pos
      }
      if received_size.to_s != opt[:file_size]
        warn "File size mismatch for '#{filename}'. Expected #{opt[:file_size].to_s}. Got #{received_size.to_s}."
      end
    }
  end

end
