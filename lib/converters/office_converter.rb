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

    Application.debug(self.class.name) { "Initializing #{self.class} with '#{source}'" }
  end

  def do_convert(target, format)
    unless format == :PDF
      Application.error(self.class.name) { "Wrong target format requested: '#{format.to_s}'."}
      return nil
    end
    cmd = 'office_convert'
    cmd += %{ "#{File.absolute_path(@source).to_s.escape_for_cmd}"}
    cmd += %{ "#{File.absolute_path(target).to_s.escape_for_cmd}"}
    cmd += %{ "#{@options[:orig_fname].to_s.decode_visual.gsub(/^\d+_/, '').escape_for_cmd}"}

    Application.debug(self.class.name) { "Running converter command: '#{cmd}'"}

    result = `#{cmd}`

    Application.debug(self.class.name) { "Result: '#{result}'"}

    target

  end

end
