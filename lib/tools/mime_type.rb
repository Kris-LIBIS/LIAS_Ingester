# coding: utf-8

class MimeType

  def self.get( file_path )
    fp = file_path.to_s.gsub(/['"\s\[\](){}]/) { |s| '\\' + s[0].to_s }
    result = %x(file -ib #{fp}).split[0]
    if result.eql?('application/octet-stream')
      begin
        x = %x(identify -format "%m" #{fp})
        x = x.split[0] if x
        x = x.strip if x
        result = 'image/jp2' if x.eql?('JP2')
      rescue Exception
        @@logger.warn(self.class) {"Could not identify MIME type of '#{file_path.to_s}''"}
      end
    end
    result = result[0...-1] if result[-1] == ';'
    result
  end
  
end
