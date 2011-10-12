# coding: utf-8

require 'tree'
require 'highline'
require 'uri'
require 'net/http'
require 'net/https'
require 'fileutils'

require 'ingester_task'
require 'libis/record/sharepoint_record'
require 'tools/xml_document'

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

      puts record.relative_path

      next unless selection.nil? or selection.empty? or
          record.relative_path =~ /^#{selection}$/ or
          record.relative_path =~ /^#{selection}\//

      tags_not_found += record.keys - mapping.keys

      record = record.delete_if { |k, _| tags_not_found.include? k }

      debug "metadata: '#{record.inspect}''"

      count += 1
      record[:index] = count

      add record
      info "Collected #{count} records so far ..." if count % 10 == 0

    end

    info '%6d Records found.' % count

    tags_not_found.each do |tag|
      error "Label '#{tag}' not found in the mapping table."
    end

  end

  def download_files( selection, download_dir )

    FileUtils.mkpath download_dir

    visit( self[selection]) do | phase, node, _ |

      metadata = node.content

      next unless phase == :before and metadata

      next unless metadata.is_file? and metadata[:url]

      next if File.exist? File.join(download_dir, metadata.relative_path)

      command = "wget --append-output=download.log"
      command += " --force-directories --no-host-directories --cut-dirs=3"
      command += " --http-user=#{search.username} --http-passwd='#{search.password}'"
      command += " --directory-prefix='#{download_dir}' #{metadata[:url]}"

      system command

=begin
      path = File.join( download_dir, File.dirname( metadata.relative_path ) )

      FileUtils.mkpath path

      http_to_file metadata.relative_path, metadata[:url], username: username, password: password
=end

    end

  end
  
  def visit( tree_node = @root_node, options = {}, &block )
    tree_node.children.each do |child|
      my_options = options.dup
      yield :before, child, my_options
      visit child, my_options, &block
      yield :after, child, my_options
    end
  end

  def save( file )
    File.open(file, 'wb') do |f|
      Marshal::dump self, f
    end
  end

  def self.open( file )
    tree = nil
    File.open(file, 'rb') do |f|
      #noinspection RubyResolve
      tree = Marshal.load(f)
    end
    tree
  end

=begin
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

=end

  protected
  
  # Copied from http://stackoverflow.com/questions/2263540/how-do-i-download-a-binary-file-over-http-using-ruby
  def http_to_file(filename, url, opt={})
    opt = {
        :ssl => false,        #user
        :init_pause => 0.1,   #start by waiting this long each time
                              # it's deliberately long so we can see
                              # what a full buffer looks like
        :learn_period => 0.3, #keep the initial pause for at least this many seconds
        :drop => 1.5,         #fast reducing factor to find roughly optimized pause time
        :adjust => 1.05       #during the normal period, adjust up or down by this factor
    }.merge(opt)
    pause = opt[:init_pause]
    learn = 1 + (opt[:learn_period]/pause).to_i
    drop_period = true
    #delta = 0
    max_delta = 0
    last_pos = 0
    File.open(filename, 'w') { |f|
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = opt[:ssl]
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(opt[:username], opt[:password])
      http.request(request) { |response|
        response.read_body { |seg|
          f << seg
          delta = f.pos - last_pos
          last_pos += delta
          if delta > max_delta then
            max_delta = delta
          end
          if learn <= 0 then
            learn -= 1
          elsif delta == max_delta then
            if drop_period then
              pause /= opt[:drop_factor]
            else
              pause /= opt[:adjust]
            end
          elsif delta < max_delta then
            drop_period = false
            pause *= opt[:adjust]
          end
          sleep(pause)
        }
      }
    }
  end

end
