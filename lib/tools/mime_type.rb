# coding: utf-8

require 'tools/string'
require 'csv'
require 'stringio'

require 'ingester_task'


class MimeType
  include IngesterTask

  BAD_MIMETYPES = %w(None)

  #noinspection RubyLiteralArrayInspection
  RETRY_MIMETYPES = [
      'application/rtf',
      'text/rtf'
  ] + BAD_MIMETYPES

  #noinspection RubyLiteralArrayInspection
  FIDO_FORMATS = [
      "#{$application_dir}/config/lias_formats.xml"
  ]

  def capture_stderr
    # The output stream must be an IO-like object. In this case we capture it in
    # an in-memory IO object so we can return the string value. You can assign any
    # IO object here.
    previous_stderr, $stderr = $stderr, StringIO.new
    yield
    $stderr.string
  ensure
    # Restore the previous value of stderr (typically equal to STDERR).
    $stderr = previous_stderr
  end


  def self.get(file_path)

    fp = file_path.to_s.escape_for_string
    info "Determining MIME type of '#{fp}' ..."

    mimetype = result = nil

    # use FIDO
    cmd = "/nas/vol03/app/bin/fido -loadformats #{FIDO_FORMATS.join(',')} \"#{fp}\" 2> /dev/null "
    fido = %x(#{cmd})
    info "Fido result: '#{fido.to_s}'"
    fido_results = CSV.parse fido
    r = fido_results[0]
    if fido_results.size > 1
      while (x = fido_results.pop)
        if x[0] == "OK" && x[8] == "signature"
          r = x
          break
        end
      end
    end
    if r && r[0] == "OK"
      format = r[2]
      mimetype = r[7]
      if mimetype == "None"
        case format
          when 'fido-fmt/189.word'
            mimetype = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          when 'lias-fmt/189.word'
            mimetype = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          when 'fido-fmt/189.xl'
            mimetype = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          when 'fido-fmt/189.ppt'
            mimetype = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
          when 'x-fmt/44'
            mimetype = 'application/vnd.wordperfect'
          when 'x-fmt/394'
            mimetype = 'application/vnd.wordperfect'
          when 'fmt/95'
            mimetype = 'application/pdfa'
          when 'fmt/354'
            mimetype = 'application/pdfa'
          else
            # nothing
        end
      end
      info "Fido MIME-type: #{mimetype} (PRONOM UID: #{format})"
      result = mimetype unless BAD_MIMETYPES.include? mimetype
    end

    # use FILE
    if result.nil? or RETRY_MIMETYPES.include? mimetype
      mimetype = %x(/usr/bin/file -ib "#{fp}").strip.split(';')[0].split(',')[0]
      info "File result: '#{mimetype}'"
      result = mimetype unless BAD_MIMETYPES.include? mimetype
    end

    # determine XML type
    if result == 'text/xml'
      doc = XmlDocument.open file_path
      if doc.validates_against?(File.join(Application.dir, 'config', 'sharepoint', 'map_xml.xsd').to_s)
        result = 'text/xml/sharepoint_map'
      elsif doc.validates_against?(File.join(Application.dir, 'config', 'ead.xsd').to_s)
        result = 'archive/ead'
      end
    end

    # use ImageMagik's identify to detect JPeg 2000 files
    if result.nil?
      begin
        x = %x(identify -format "%m" "#{fp}")
        info "Identify result: '#{x.to_s}'"
        x = x.split[0].strip if x
        result = 'image/jp2' if x == 'JP2'
      rescue Exception
        # ignored
      end
    end

    result ? info("Final MIME-type: '#{result}'") : warn("Could not identify MIME type of '#{fp}'")

    result
  end

end
