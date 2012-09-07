# coding: utf-8

require 'converters/converter'

module DummyConverter

  def DummyConverter.included(klass)
    klass.class_eval {
      def self.config_file
        'test/data/' + self.name.underscore + '.yaml'
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
