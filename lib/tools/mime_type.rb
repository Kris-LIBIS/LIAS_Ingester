# coding: utf-8

require 'tools/string'
require 'csv'
require 'stringio'

require 'ingester_task'


class MimeType
  include IngesterTask

  BAD_MIMETYPES = [
      'application/octet-stream',
      'application/x-empty',
      'CDF V2 Document'
  ]

  #noinspection RubyLiteralArrayInspection
  RETRY_MIMETYPES = [
      'application/vnd.ms-office',
      'application/zip',
      'application/x-zip',
      'image/x-3ds',
      'text/plain',
      'video/x-ms-asf'
  ] + BAD_MIMETYPES

  #noinspection RubyLiteralArrayInspection
  FIDO_FORMATS = [
      '/nas/vol03/app/depot/fido/fido/conf/formats.xml',
      '/nas/vol03/app/depot/fido/fido/conf/format_extensions.xml'
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


  def self.get( file_path )

    fp = file_path.to_s.escape_for_string
    debug "Determining MIME type of '#{fp}' ..."

    result = nil

    # use FILE
    mimetype = %x(/usr/bin/file -ib "#{fp}").strip.split(';')[0].split(',')[0]
    debug "File result: '#{mimetype}'"
    result = mimetype unless BAD_MIMETYPES.include? mimetype

    # use FIDO
    if result.nil? or RETRY_MIMETYPES.include? mimetype
      fido = %x(/nas/vol03/app/bin/fido -loadformats #{FIDO_FORMATS.join(',')} "#{fp}" 2>/dev/null)
      debug "Fido result: '#{fido.to_s}'"
      r = CSV.parse(fido)[0]
      if r && r[0] == "OK"
        format = r[2]
        mimetype = r[7]
        if mimetype == "None"
          case format
            when 'fido-fmt/189.word'
              mimetype = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            when 'fido-fmt/189.xl'
              mimetype = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            when 'fido-fmt/189.ppt'
              mimetype = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
            when 'x-fmt/44'
              mimetype = 'application/vnd.wordperfect'
            when 'x-fmt/394'
              mimetype = 'application/vnd.wordperfect'
            else
              # nothing
          end
        end
        debug "Fido MIME-type: #{mimetype} (PRONOM UID: #{format})"
        result = mimetype unless mimetype == "None"
      end
    end

    # use ImageMagik's identify to detect JPeg 2000 files
    if result.nil?
      begin
        x = %x(identify -format "%m" "#{fp}")
        debug "Identify result: '#{x.to_s}'"
        x = x.split[0].strip if x
        result = 'image/jp2' if x == 'JP2'
      rescue Exception
        # ignored
      end
    end

    result ? debug("Final MIME-type: '#{result}'") : warn("Could not identify MIME type of '#{fp}'")

    result
  end

end
