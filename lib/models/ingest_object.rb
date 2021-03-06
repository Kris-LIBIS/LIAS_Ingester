# coding: utf-8

require 'dm-is-tree'
require 'fileutils'
require 'pathname'

require_relative 'common/status'

#noinspection RubyResolve
class IngestObject
  include DataMapper::Resource
  
  property    :id,              DataMapper::Property::Serial, :key => true
  property    :created_at,      DataMapper::Property::Date
  property    :updated_at,      DataMapper::Property::Date
  property    :status,          DataMapper::Property::Integer, :default => Status::New
  property    :status_name,     DataMapper::Property::String
  property    :label_name,      DataMapper::Property::String #, :index => :label_idx
  property    :usage_type,      DataMapper::Property::String #, :index => :usage_type_idx
  property    :metadata,        DataMapper::Property::FilePath
  property    :metadata_mid,    DataMapper::Property::Integer
  
  property    :file_stream,     DataMapper::Property::FilePath
  property    :vpid,            DataMapper::Property::String #, :index => :vpid_idx
  property    :pid,             DataMapper::Property::String #, :index => :pid_idx
  property    :message,         DataMapper::Property::String
  property    :tree_index,      DataMapper::Property::Integer
  property    :more_info,       DataMapper::Property::Text
  
  has 1,      :file_info

  is          :tree,            order: :id, required: false
  
  has n,      :manifestations,  'IngestObject', child_key: :master_id
  
  has n,      :log_entries,     child_key: :ingest_object_id
  
  belongs_to  :ingest_run,      required: false
  belongs_to  :ingest_config,   required: false
  belongs_to  :master,          required: false, model: "IngestObject", child_key: :master_id

  belongs_to  :accessright_model,required: false
  belongs_to  :accessright,     required: false

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
    nil
  end
  
  def get_run
    return self.ingest_run if self.ingest_run
    get_config.ingest_run
  end
  
  def initialize(file_path = nil, checksum_type = nil)
    if file_path
      self.file_info      = FileInfo.new(file_path, checksum_type)
      self.label_name     = self.file_info.base_name
      self.usage_type     = 'ORIGINAL'
    end
    self.message        = ''
    self.status         = Status::New
    self.accessright    = nil
  end

  def recalculate_checksums
    self.file_info.recalculate_checksums
  end

  def get_accessright_model
    obj =  get_master
    unless obj.accessright_model
      cfg_or_run = obj.ingest_config || obj.ingest_run
      obj.accessright_model = cfg_or_run.get_accessright_model obj if cfg_or_run
    end
    obj.accessright_model
  end

  def get_accessright()
    unless self.accessright
      ar_model = get_accessright_model
      usagetype = self.usage_type
      usagetype = usagetype.to_s.downcase
      usagetype = 'archive' if usagetype == 'original'
      self.accessright = ar_model.get_accessright(usagetype)
    end
    self.accessright
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
  
  def get_master()
    self.master || self
  end

  def manifestation?
    !self.master.nil?
  end
  
  def file_path
    return self.file_info.file_path if self.file_info
    nil
  end
  
  def flattened_path
    fp = self.file_path
    return fp.to_s.gsub('/', '_') if fp
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
  
  def absolute_path
    file_path.expand_path
  end
  
  def relative_path
    return nil unless get_run
    location = Pathname.new( get_run.location ).expand_path
    absolute_path.relative_path_from location
  end
  
  def flattened_relative
    fp = relative_path
    return fp.to_s.gsub('/', '_').gsub(' ','_0x020_') if fp
    nil
  end

  def stream_name
    #flattened_relative
    id.to_s + '_' + file_name.remove_whitespace.encode_visual(/[^\w.]/)
  end
  
  def relative_stream
    return nil unless get_config
    stream_root = Pathname.new get_config.ingest_dir
    stream_root += 'transform/streams'
    self.file_stream.relative_path_from stream_root
  end
  
  def mime_type
    return self.file_info.mime_type if self.file_info
    nil
  end

  def label=(value)
    self.label_name = value
  end
  
  def label
    return self.label_name if self.label_name
    return self.master.label if self.master
    nil
  end
  
  def label_path
    path = label
    node = self.master ? self.master.parent : self.parent
    while node
      path = node.label + "/" + path
      node = node.parent
    end
    path
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
    nil
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
    self.protection.debug_print indent
    self.children.each { |i| i.debug_print indent }
  end
  
end
