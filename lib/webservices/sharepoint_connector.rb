# coding: utf-8

require_relative 'soap_client'

module Savon
  module SOAP
    class XML
      def namespace_by_uri(uri)
        namespaces.each do |candidate_identifier, candidate_uri|
          return namespace_identifier if uri == namespace
          return candidate_identifier.gsub(/^xmlns:/, '') if candidate_uri == uri
        end
        nil
      end

      private

      def body_to_xml
        return body.to_s unless body.kind_of? Hash
        Gyoku.xml add_namespaces_to_body(body), :element_form_default => element_form_default, :namespace => namespace_identifier
      end

    end
  end
end

class SharepointConnector

  protected

  def result_parser( result )

    records = []
    result = result[:get_list_items_response][:get_list_items_result]

    data = result[:listitems][:data]

    rows = data[:row]
    rows = [rows] unless rows.is_a? Array

    #noinspection RubyResolve
    rows.each do | row |
      #noinspection RubyResolve
      if @selection.nil? or row[:ows_FileRef] =~ /^\d+;#sites\/lias\/Gedeelde documenten\/#@selection($|\/)/
        records << clean_row( row )
      end
    end

    next_set = data[:@list_item_collection_position_next]

    count = records.size

    { next_set: next_set, records: records, count: count }

  end

  def clean_row( row )

    @fields_found ||= Set.new
    row.keys.each { |k| @fields_found << k }

    fields_to_be_removed = [:ows_MetaInfo]
    #noinspection RubyResolve
    fields_to_be_removed = row.keys - @field_selection if @field_selection

    record = SharepointRecord.new

    row.each do | k, v |
      key = k.to_s.gsub(/^@/, '').to_sym
      next if fields_to_be_removed.include? key
      record[key] = v.dot_net_clean
    end

    record

  end

end