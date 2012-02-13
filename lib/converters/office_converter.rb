# coding: utf-8

require_relative 'converter'

class OfficeConverter < Converter

  def initialized?
    true
  end

  protected

  def init(source)
    @source = source
    @options = { orig_fname: File.basename(source)}

    puts "Initializing #{self.class} with '#{source}'"
  end

  def do_convert(target, format)
    unless format == :PDF
      Application.error(self.class.name) { "Wrong target format requested: '#{format.to_s}'."}
      return nil
    end
    cmd = "ssh -i ~/.ssh/pdfconvert pdfconvert@10.32.32.167 \"#{@source}\" \"#{target}\""
    cmd += " \"#{@options[:orig_fname].sub(' ', '\\ ')}\""

    `#{cmd}`

    target

  end

end
