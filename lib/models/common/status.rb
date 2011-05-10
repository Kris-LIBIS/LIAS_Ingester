# centralized status number management

#noinspection ALL
module Status


  # Phase  
  Idle              = 0x0010                    # 16
  Initialize        = 0x0020                    # 32
  PreProcess        = 0x0030                    # 48
  PreIngest         = 0x0040                    # 64
  Ingest            = 0x0050                    # 80
  PostIngest        = 0x0060                    # 96

  # Status in phase
  Running           = 0x0001                    # 1
  Failed            = 0x0004                    # 4
  Done              = 0x0008                    # 8

  # Status
  New               = Idle + Running            # 17

  Initializing      = Initialize + Running      # 33
  InitializeFailed  = Initialize + Failed       # 36
  Initialized       = Initialize + Done         # 40

  PreProcessing     = PreProcess + Running      # 49
  PreProcessFailed  = PreProcess + Failed       # 52
  PreProcessed      = PreProcess + Done         # 56

  PreIngesting      = PreIngest  + Running      # 65
  PreIngestFailed   = PreIngest  + Failed       # 68
  PreIngested       = PreIngest  + Done         # 72

  Ingesting         = Ingest     + Running      # 81
  IngestFailed      = Ingest     + Failed       # 84
  Ingested          = Ingest     + Done         # 88

  PostIngesting     = PostIngest + Running      # 97
  PostIngestFailed  = PostIngest + Failed       # 100
  PostIngested      = PostIngest + Done         # 104

  Finished          = 0x00F0     + Done         # 248

  StatusMap = {
    Idle              => 'Idle',
    Initialize        => 'Initialize',
    PreProcess        => 'PreProcess',
    PreIngest         => 'PreIngest',
    Ingest            => 'Ingest',
    PostIngest        => 'PostIngest',
    
    Running           => 'Running',
    Done              => 'Done',
    Failed            => 'Failed',
    
    New               => 'New',
    Initializing      => 'Initializing',
    Initialized       => 'Initialized',
    InitializeFailed  => 'InitializeFailed',
    PreProcessing     => 'PreProcessing',
    PreProcessed      => 'PreProcessed',
    PreProcessFailed  => 'PreProcessFailed',
    PreIngesting      => 'PreIngesting',
    PreIngested       => 'PreIngested',
    PreIngestFailed   => 'PreIngestFailed',
    Ingesting         => 'Ingesting',
    Ingested          => 'Ingested',
    IngestFailed      => 'IngestFailed',
    PostIngesting     => 'PostIngesting',
    PostIngested      => 'PostIngested',
    PostIngestFailed  => 'PostIngestFailed',
    Finished          => 'Finished'
  }

  def self.running?(status)
    (status & Running) == Running
  end

  def self.done?(status)
    (status & Done) == Done
  end

  def self.failed?(status)
    (status & Failed) == Failed
  end

  def self.phase(status)
    status & 0xFFF0
  end

  def self.to_string(status)
    StatusMap[status]
  end

  def self.to_status(string)
    StatusMap.key(string)
  end

end
