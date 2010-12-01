class LogEntry
  include DataMapper::Resource

  property    :id,              Serial, :key => true
  property    :created_at,      DateTime
  property    :severity,        String
  property    :program,         String
  property    :message,         String, :length => 1024
  
  belongs_to  :ingest_run,      :required => false
  belongs_to  :ingest_config,   :required => false
  belongs_to  :ingest_object,   :required => false

end
