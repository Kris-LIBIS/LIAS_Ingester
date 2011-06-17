require 'set'

require 'ingester_task'

require_relative 'converter_chain'

class ConverterRepository
  include IngesterTask

  @@converters = Set.new

  @@converters_glob = "#{Application.dir}/lib/converters/*_converter.rb"

  def ConverterRepository.register converter_class
    @@converters.add? converter_class
  end

  #noinspection RubyResolve
  def ConverterRepository.get_converters
    if @@converters.empty?
      Dir.glob(@@converters_glob).each do |f|
        require f
      end
      @@converters.each { |c| c.load_config}
    end
    @@converters
  end

  def ConverterRepository.get_converter_chain(src_type, tgt_type, operations = nil)
    msg = "conversion from #{src_type.to_s} to #{tgt_type.to_s}"
    chain_list = self.get_converter_chain_recursive src_type, tgt_type, operations
    if chain_list.length > 1
      warn "Found more than one conversion chain for #{msg}. Picking the first one."
    end
    if chain_list.empty?
      error "No conversion chain found for #{msg}"
      return nil
    end
    chain_list.each do |chain|
      msg = "Converter chain: #{src_type.to_s}"
      chain.each do |node|
        msg += "->#{node[:converter].name}:#{node[:target].to_s}"
      end
      debug msg
    end
    ConverterChain.new(chain_list[0])
  end

  private

  def ConverterRepository.get_converter_chain_recursive(src_type, tgt_type, operations, chains_found = [], current_chain = [])
    return chains_found unless current_chain.length < 8 # upper limit of converter chain we want to consider

    self.get_converters.each do |converter|
      if converter.support_conversion? src_type, tgt_type and !current_chain.any? { |c|
        c[:converter] == converter and c[:target] == tgt_type }
        node = Hash.new
        node[:converter] = converter
        node[:target] = tgt_type
        sequence = current_chain.dup
        sequence << node
        # we only want to remember the shortest converter chains
        if !chains_found.empty? and sequence.length < chains_found[0].length
          chains_found.clear
        end
        chains_found << sequence if chains_found.empty? or sequence.length == chains_found[0].length
      end
    end

    return chains_found unless chains_found.empty? or current_chain.length + 1 < chains_found[0].length

    self.get_converters.each do |converter|
      next unless converter.support_input_type? src_type
      converter.supported_output_types(src_type).each do |tmp_type|
        next if tmp_type == src_type
        next if current_chain.any? { |c| c[:target] == tmp_type}
        self.get_converter_chain_recursive(tmp_type, tgt_type, operations, chains_found,
                                           current_chain.dup << { :converter => converter, :target => tmp_type })
      end
    end

    chains_found
  end

end