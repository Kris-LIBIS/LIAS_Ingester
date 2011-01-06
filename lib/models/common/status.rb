# centralized status number management

module Status

  Idle              = 0x0000
  Running           = 0x0001
  Done              = 0x0002
  Failed            = 0x0008

  New               = Idle + Running            # 1

  Initialize        = 0x0020                    # 32
  Initializing      = Initialize + Running      # 33
  Initialized       = Initialize + Done         # 34
  InitializeFailed  = Initialize + Failed       # 40

  PreProcess        = 0x0030                    # 48
  PreProcessing     = PreProcess + Running      # 49
  PreProcessed      = PreProcess + Done         # 50
  PreProcessFailed  = PreProcess + Failed       # 56

  PreIngest         = 0x0040                    # 64
  PreIngesting      = PreIngest  + Running      # 65
  PreIngested       = PreIngest  + Done         # 66
  PreIngestFailed   = PreIngest  + Failed       # 72

  Ingest            = 0x0050                    # 80
  Ingesting         = Ingest     + Running      # 81
  Ingested          = Ingest     + Done         # 82
  IngestFailed      = Ingest     + Failed       # 88

  PostIngest        = 0x0060                    # 96
  PostIngesting     = PostIngest + Running      # 97
  PostIngested      = PostIngest + Done         # 98
  PostIngestFailed  = PostIngest + Failed       # 104

  Final             = 0x00F0     + Done         # 240

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
    Final             => 'Final'}

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
