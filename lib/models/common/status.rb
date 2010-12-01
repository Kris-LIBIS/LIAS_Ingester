# centralized status number management

module Status

  Idle              = 0x0000
  Running           = 0x0001
  Done              = 0x0002
  Failed            = 0x0008

  New               = Idle + Running

  Initialize        = 0x0020
  Initializing      = Initialize + Running
  Initialized       = Initialize + Done
  InitializeFailed  = Initialize + Failed

  PreProcess        = 0x0030
  PreProcessing     = PreProcess + Running
  PreProcessed      = PreProcess + Done
  PreProcessFailed  = PreProcess + Failed

  PreIngest         = 0x0040
  PreIngesting      = PreIngest  + Running
  PreIngested       = PreIngest  + Done
  PreIngestFailed   = PreIngest  + Failed

  Ingest            = 0x0050
  Ingesting         = Ingest     + Running
  Ingested          = Ingest     + Done
  IngestFailed      = Ingest     + Failed

  PostIngest        = 0x0060
  PostIngesting     = PostIngest + Running
  PostIngested      = PostIngest + Done
  PostIngestFailed  = PostIngest + Failed

  Final             = 0x00F0     + Done

  def self.failed?(status)
    (status & Failed) == Failed
  end

end
