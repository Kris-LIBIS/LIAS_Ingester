require 'dm-is-tree'
require File.dirname(__FILE__) + '/common/status'

class IngestObject
  include DataMapper::Resource

  property    :id,              Serial, :key => true
  property    :created_at,      Date
  property    :updated_at,      Date
  property    :status,          Integer, :default => Status::New
  property    :label,           String#, :index => :label_idx
  property    :usage_type,      String#, :index => :usage_type_idx
  property    :metadata,        FilePath

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
    self.file_info.destroy
    self.children.destroy
    self.manifestations.destroy
    self.log_entries.destroy
    true
  end

  before :save do
#    self.debug_print
  end

  def get_config
    return self.ingest_config unless self.parent
    child = parent = self
    until parent.nil?
      child = parent
      parent = child.parent
    end
    child.ingest_config
  end

  def get_run
    return self.ingest_run if self.ingest_run
    get_config.ingest_run
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
    self.parent.nil? && self.master.nil?
  end

  def leaf?
    self.children.empty?
  end

  def child?
    self.parent
  end

  def parent?
    self.children.size !=0
  end

  def branch?
    self.parent && self.children.size != 0
  end

  def master?
    self.manifestations.size != 0
  end

  def manifestation?
    self.master
  end

  def file_path
    return self.file_info.file_path if self.file_info
    nil
  end

  def base_name
    return self.file_info.base_name if self.file_info
    nil
  end

  def file_name
    return self.file_info.file_name if self.file_info
    nil
  end

  def mime_type
    return self.file_info.mime_type if self.file_info
    nil
  end

  def label
    return super if super
    return self.master.label if self.master
    nil
  end

  def metadata
    return super if super
    return self.master.metadata if self.master
    nil
  end

  def get_checksum( checksum_type )
    return self.file_info.get_checksum(checksum_type) if self.file_info
    nil
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
