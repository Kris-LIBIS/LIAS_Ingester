require 'converters/converter'

module TestConverter

  def TestConverter.included(klass)
    klass.class_eval {
      def self.config_file
        File.dirname(__FILE__) + '/' + self.name.underscore + '.yaml'
      end
    }
  end

  protected

  def init(source)
    @source = source
  end

  def do_convert(target, _)
    FileUtils.touch target
  end

end