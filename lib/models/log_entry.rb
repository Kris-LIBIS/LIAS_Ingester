require "dm-core"

#noinspection RubyResolve
class LogEntry
  include DataMapper::Resource

  property    :id,              Serial, :key => true
  property    :created_at,      DateTime
  property    :severity,        String
  property    :program,         String, :index => :program_idx
  property    :message,         String, :length => 1024
  
  belongs_to  :ingest_run,      :required => false
  belongs_to  :ingest_config,   :required => false
  belongs_to  :ingest_object,   :required => false
  
  def to_s
    "#{self.ingest_run ? self.ingest_run.id : '---'} #{self.ingest_config ? self.ingest_config.id : '---'} #{self.ingest_object ? self.ingest_object.id : '---'} [#{self.created_at.to_s}] #{self.severity} -- #{self.program}: #{self.message}"
  end

end
