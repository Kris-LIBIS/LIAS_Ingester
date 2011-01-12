# centralized status number management

module Status

  private

  Idle              = 0x0000
  Running           = 0x0001
  Failed            = 0x0004
  Done              = 0x0008
  
  public

  New               = Idle + Running            # 1

  Initialize        = 0x0020                    # 32
  Initializing      = Initialize + Running      # 33
  InitializeFailed  = Initialize + Failed       # 36
  Initialized       = Initialize + Done         # 40

  PreProcess        = 0x0030                    # 48
  PreProcessing     = PreProcess + Running      # 49
  PreProcessFailed  = PreProcess + Failed       # 52
  PreProcessed      = PreProcess + Done         # 56

  PreIngest         = 0x0040                    # 64
  PreIngesting      = PreIngest  + Running      # 65
  PreIngestFailed   = PreIngest  + Failed       # 68
  PreIngested       = PreIngest  + Done         # 72

  Ingest            = 0x0050                    # 80
  Ingesting         = Ingest     + Running      # 81
  IngestFailed      = Ingest     + Failed       # 84
  Ingested          = Ingest     + Done         # 88

  PostIngest        = 0x0060                    # 96
  PostIngesting     = PostIngest + Running      # 97
  PostIngestFailed  = PostIngest + Failed       # 100
  PostIngested      = PostIngest + Done         # 104

  Finished          = 0x00F0     + Done         # 248

  StatusMap = {
    Idle              => 'Idle',
    Running           => 'Running',
    Done              => 'Done',
    Failed            => 'Failed',
    Initialize        => 'Initialize',
    Initializing      => 'Initializing',
    InitializeFailed  => 'InitializeFailed',
    PreProcess        => 'PreProcess',
    PreProcessing     => 'PreProcessing',
    PreProcessed      => 'PreProcessed',
    PreProcessFailed  => 'PreProcessFailed',
    PreIngest         => 'PreIngest',
    PreIngesting      => 'PreIngesting',
    PreIngested       => 'PreIngested',
    PreIngestFailed   => 'PreIngestFailed',
    Ingest            => 'Ingest',
    Ingesting         => 'Ingesting',
    Ingested          => 'Ingested',
    IngestFailed      => 'IngestFailed',
    PostIngest        => 'PostIngest',
    PostIngesting     => 'PostIngesting',
    PostIngested      => 'PostIngested',
    PostIngestFailed  => 'PostIngestFailed',
    Finished          => 'Finished'}

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
