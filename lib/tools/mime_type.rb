# coding: utf-8

require 'tools/string'
require 'faster_csv'

class MimeType

  def self.get( file_path )

    # first attempt: use FIDO

    fp = file_path.to_s.escape_for_string
    result = %x(fido -loadformats #{Application.dir}/config/lias_formats.xml "#{fp}")
    r = FasterCSV.parse(result)[0]
    status = r[0]
    format = r[2]
    mimetype = r[7]
    return mimetype if status == "OK" && mimetype != "None"

    # second attempt: use FILE
    result = %x(file -ib "#{fp}").split[0]
    return result unless result.eql?('application/octet-stream')

    # final attempt: use ImageMagik's identify
    begin
      x = %x(identify -format "%m" #{fp})
      x = x.split[0] if x
      x = x.strip if x
      result = 'image/jp2' if x.eql?('JP2')
    rescue Exception
      @@logger.warn(self.class) {"Could not identify MIME type of '#{file_path.to_s}''"}
      result = ""
    end

    result[-1] == ';' ? result[0...-1] : result

  end
  
end
