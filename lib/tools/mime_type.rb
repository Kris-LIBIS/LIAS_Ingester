class MimeType

  def self.get( file_path )
    result = %x(file -ib #{file_path}).split[0]
    if result.eql?('application/octet-stream')
      x =  %x(identify -format "%m" #{file_path}).split[0].strip
      result = 'image/jp2' if x.eql?('JP2')
    end
    result
  end
  
end
