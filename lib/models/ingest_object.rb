require 'dm-is-tree'
require 'fileutils'
require 'pathname'
require_relative 'common/status'

class IngestObject
  include DataMapper::Resource
  
  property    :id,              Serial, :key => true
  property    :created_at,      Date
  property    :updated_at,      Date
  property    :status,          Integer, :default => Status::New
  property    :status_name,     String
  property    :label,           String#, :index => :label_idx
  property    :usage_type,      String#, :index => :usage_type_idx
  property    :metadata,        FilePath
  property    :metadata_mid,    Integer
  
  property    :file_stream,     FilePath
  property    :vpid,            String#, :index => :vpid_idx
  property    :pid,             String#, :index => :pid_idx
  property    :message,         String
  property    :more_info,       Text
  
  has 1,      :file_info
  
  is          :tree, :order => :id, :required => false
  
  has n,      :manifestations,  'IngestObject', :child_key => :master_id
  
  has n,      :log_entries, :child_key => :ingest_object_id
  
  belongs_to  :ingest_run,      :required => false
  belongs_to  :ingest_config,   :required => false
  belongs_to  :master,          :model => "IngestObject", :child_key => :master_id, :required => false
  
  before :destroy do
    self.manifestations.destroy
    self.clear_filestream
    self.clear_metadata
    self.file_info.destroy if self.file_info
    self.log_entries.destroy if self.log_entries
    self.children.clear
    true
  end
  
  after :status= do
    self.status_name = Status.to_string(self.status)
  end
  
  public
  
  def delete
    self.children.destroy
    self.destroy
  end
  
  def clear_filestream
    FileUtils.rm(self.file_stream) if self.file_stream and File.exists?(self.file_stream)
    self.file_stream = nil
  end
  
  def clear_metadata
    FileUtils.rm(self.metadata) if self.metadata and File.exists?(self.metadata)
    self.metadata = nil
  end
  
  def get_config
    return self.ingest_config if self.ingest_config
    return self.master.get_config if self.master
    return self.parent.get_config if self.parent
    return self.ingest_config unless self.parent
    return nil
  end
  
  def get_run
    return self.ingest_run if self.ingest_run
    return get_config.ingest_run
  end
  
  def initialize(file_path = nil, checksum_type = nil)
    if file_path
      self.file_info      = FileInfo.new(file_path, checksum_type)
      self.label          = self.file_info.base_name
      self.usage_type     = 'ORIGINAL'
    end
    self.message        = ''
    self.status         = Status::New
  end
  
  def root?
    return self.parent.nil? && self.master.nil?
  end
  
  def leaf?
    return self.children.empty?
  end
  
  def child?
    return self.parent
  end
  
  def parent?
    return self.children.size !=0
  end
  
  def branch?
    return self.parent && self.children.size != 0
  end
  
  def master?
    return self.manifestations.size != 0
  end
  
  def manifestation?
    return self.master
  end
  
  def file_path
    return self.file_info.file_path if self.file_info
    return nil
  end
  
  def flattened_path
    fp = self.file_path
    return fp.to_s.gsub('/', '_') if fp
    return nil
  end
  
  def base_name
    return self.file_info.base_name if self.file_info
    return nil
  end
  
  def file_name
    return self.file_info.file_name if self.file_info
    return nil
  end
  
  def absolute_path
    return file_path.expand_path
  end
  
  def relative_path
    return nil unless get_run
    location = Pathname.new( get_run.location ).expand_path
    return absolute_path.relative_path_from location
  end
  
  def flattened_relative
    fp = relative_path
    return fp.to_s.gsub('/', '_') if fp
    return nil
  end
  
  def relative_stream
    return nil unless get_config
    stream_root = Pathname.new get_config.ingest_dir
    stream_root += 'transform/streams'
    return file_stream.relative_path_from stream_root
  end
  
  def mime_type
    return self.file_info.mime_type if self.file_info
    return nil
  end
  
  def label
    return super if super
    return self.master.label if self.master
    return nil
  end
  
  def metadata
    return super if super
    return self.master.metadata if self.master
    return nil
  end
  
  def get_checksum( checksum_type )
    return self.file_info.get_checksum(checksum_type) if self.file_info
    return nil
  end
  
  def add_child( object )
    self.children << object
  end
  
  def del_child( object )
    self.children.delete object
  end
  
  def add_manifestation( object )
    self.manifestations << object
    object.master = self
  end
  
  def del_manifestation( object )
    self.manifestations.delete object
    object.master = nil
  end
  
  def get_manifestation( usage_type )
    return self if self.usage_type == usage_type
    self.manifestations.each do |m|
      return m if m.usage_type == usage_type
    end
    return nil
  end
  
  def set_status_recursive( status, old_status = nil )
    self.status = status if old_status.nil? or self.status == old_status
    self.manifestations.each  { |obj| obj.set_status_recursive status, old_status }
    self.children.each        { |obj| obj.set_status_recursive status, old_status }
  end
  
  def debug_print( indent = 0 )
    p ' ' * indent + self.inspect
    indent += 2
    self.file_info { |i| i.debug_print }
    self.manifestations.each  { |i| i.debug_print indent }
    self.children.each { |i| i.debug_print indent }
  end
  
end
