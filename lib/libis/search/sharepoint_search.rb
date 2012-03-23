# coding: utf-8

require 'highline'

require 'webservices/soap_client'
require 'tools/string'
require 'libis/record/sharepoint_record'

require_relative 'generic_search'

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

#noinspection RubyTooManyInstanceVariablesInspection
class SharepointSearch < GenericSearch
  include SoapClient

  private

  #noinspection RubyStringKeysInHashInspection
  MY_QUERY_SYMBOLS = {
      nil => 'Eq',
      '==' => 'Eq',
      '!=' => 'Neq',
      '>' => 'Gt',
      '>=' => 'Geq',
      '<' => 'Lt',
      '<=' => 'Leq',
      'is null' => 'IsNull'
  }

  public

  def initialize
    @options = {}
    @options[:ssl] = true
    init
    @server_url = 'https://www.groupware.kuleuven.be/sites/lias/'
    @base_url = @server_url + '_vti_bin/'
    @options[:wsdl_url] = "https://#{CGI.escape(username)}:#{CGI.escape(password)}@www.groupware.kuleuven.be/sites/lias/_vti_bin/Lists.asmx?wsdl"
    setup 'Lists.asmx', @options
  end

  def username
    return @username if @username
    highline = HighLine.new($stdin, $stderr)
    @username = highline.ask('User name (u-number): ') { |q| q.echo = true }.chomp
  end

  def password
    return @password if @password
    highline = HighLine.new($stdin, $stderr)
    @password = highline.ask("Password for #{self.username}: ") { |q| q.echo = '*'}.chomp
  end

  def query(term, index, base, options = {})

    @term = term
    @index = index
    @base = base

    @options[:username] ||= self.username
    @options[:password] ||= self.password

    @limit = options.delete(:limit) || 100
    @value_type = options.delete(:value_type) || 'Text'
    @query_operator = MY_QUERY_SYMBOLS[options.delete(:query_operator) || '==']

    @query_operator = 'BeginsWith' if term =~ /^[^*]+\*$/
    @query_operator = 'Contains' if term =~ /^\*[^*]+\*$/

    @selection = options.delete(:selection) || nil

    @field_selection = options.delete(:field_selection)

    @options.merge! options

    restart_query

  end

  def each

    # we start with a new search
    restart_query
    get_next_set

    while records_to_process?

      yield @result[:records][@current]

      @current += 1

      get_next_set if require_next_set?

    end

    restart_query

  end

  protected

  def restart_query
    @result = nil
    @current = 0
    @set_count = 0
    @next_set = nil
  end

  def records_to_process?
    @current < @set_count
  end

  def require_next_set?
    @current >= @set_count and @next_set
  end

  def get_next_set

    @current = 0

    begin

      #noinspection RubyStringKeysInHashInspection
      query = {
          'Query' => {
              'Where' => {
                  @query_operator  => {
                      'FieldRef' => '',
                      'Value' => @term,
                      :attributes! => {
                          'FieldRef' => {
                              'Name' => @index
                          },
                          'Value' => {
                              'Type' => @value_type
                          }
                      }
                  }
              }
          }
      }

      #noinspection RubyStringKeysInHashInspection
      query_options =  {
          'QueryOptions' => {
              'ViewAttributes' => '',
              :attributes! => {
                  'ViewAttributes' => {
                      'Scope' => "RecursiveAll"
                  }
              }
          }
      }

      if @next_set
        query_options['QueryOptions']['Paging'] = ''
        #noinspection RubyStringKeysInHashInspection
        query_options['QueryOptions'][:attributes!]['Paging'] = {'ListItemCollectionPositionNext' => @next_set}
      end

      #noinspection RubyStringKeysInHashInspection
      result = request 'GetListItems', {
          soap_options: {
              endpoint: 'https://www.groupware.kuleuven.be/sites/lias/_vti_bin/lists.asmx'
          },
          wsse_options: @options,
          listName: @base,
          viewName: '',
          query: query,
          viewFields: { 'ViewFields' => '' },
          rowLimit: @limit.to_s,
          query_options: query_options,
          webID: ''
      }

      @result = result
      @set_count = result[:count]
      @next_set = result[:next_set]

    end while @set_count == 0 and @next_set

  end

  def result_parser( result )

    records = []
    result = result[:get_list_items_response][:get_list_items_result]

    data = result[:listitems][:data]

    rows = data[:row]
    rows = [rows] unless rows.is_a? Array

    #noinspection RubyResolve
    rows.each do | row |
      if @selection.nil? or row[:ows_FileRef] =~ /^\d+;#sites\/lias\/Gedeelde documenten\/#{@selection}($|\/)/
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
