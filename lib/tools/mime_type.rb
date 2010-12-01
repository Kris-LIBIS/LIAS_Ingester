class MimeType

  def self.get( file_path )
    %x(file -ib #{file_path})
  end
  
end
