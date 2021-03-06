# coding: utf-8

require 'fileutils'

require 'ingester_task'

require_relative 'type_database'

class ConverterChain
  include IngesterTask

  def initialize(converter_chain)
    @converter_chain = converter_chain
  end

  def to_array
    @converter_chain
  end

  def convert(src_file, target_file, operations = [])

    chain = @converter_chain.clone

    my_operations = {}

    # sanity check: check if the required operations are supported by at least one converter in the chain
    operations.each do |k,v|
      method = k.to_s.downcase.to_sym
      chain_element = @converter_chain.reverse.detect { |c| c[:converter].new.respond_to? method }
      if chain_element
        my_operations[chain_element[:converter]] ||= {}
        my_operations[chain_element[:converter]][method] = v
      else
        error "No converter in the converter chain supports '#{method.to_s}'. Continuing conversion without this operation."
      end
    end

    temp_files = []

    while (chain_element = chain.shift)

      target_type = chain_element[:target]
      converter_class = chain_element[:converter]
      converter = converter_class.new(src_file)

      my_operations[converter_class].each do |k,v|
        converter.send k, v
      end

      target = target_file

      unless chain.empty?
        target += '.temp.' + TypeDatabase.instance.type2ext(target_type)
        target += '.' + TypeDatabase.instance.type2ext(target_type) while File.exist? target
        temp_files << target
      end

      FileUtils.mkdir_p File.dirname(target)

      converter.convert(target, target_type)

      src_file = target

    end

    temp_files.each do |f|
      File.delete(f)
    end

  end

end