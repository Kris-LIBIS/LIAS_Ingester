require 'xml/libxml'
require 'tools/xml_writer'

class IngestSettings
  include XmlWriter

  attr_reader :tasks

  TaskParamOrder = {
    'MetadataInserter' =>     [ :Link, :Mddesc, :Mdfilename, :Mid, :ComplexOnly,
                                :Extension, :Size ],
    'AttributeAssignment' =>  [ :Name1, :Value1, :Name2, :Value2, :Name3, :Value3,
                                :apply_to_parent_only, :extension],
    'FullText' =>             [ :Encoding, :Extension ]
  }


  def initialize
    @tasks = Array.new
  end

  def add_metadata( options = {} )
    task              = Hash.new
    task[:task_name]  = 'MetadataInserter'
    task[:name]       = 'Add Metadata'
    params            = Hash.new
    task[:params]     = params
    params[:Link]         = ''
    params[:Mddesc]       = ''
    params[:Mdfilename]   = ''
    params[:Mid]          = ''
    params[:ComplexOnly]  = 'false'
    params[:Extension]    = ''
    params[:Size]         = ''
    options.each do |k,v|
      params[k] = v if [:Link, :Mddesc, :Mdfilename, :Mid, :ComplexOnly, :Extension, :Size].include? k
    end
    @tasks << task
  end

  def add_acl( id, options = {} )
    add_metadata({
      :Mddesc => 'accessrights rights_md',
      :Link => 'true',
      :Mid => id.to_s
    }.merge!(options))
  end

  def add_dc( file_name, options = {} )
    add_metadata({
      :Mddesc => 'descriptive dc',
      :Link => 'true',
      :Mdfilename => file_name
    }.merge!(options))
  end

  def add_control_fields( name_values, extension, options = {} )
    return unless name_values
    keys = name_values.keys
    until keys.empty?
      task              = Hash.new
      task[:task_name]  = 'AttributeAssignment'
      task[:name]       = 'Control section Attribute Assignment'
      params            = Hash.new
      task[:params]     = params
      params[:Name1]    = ''
      params[:Value1]   = ''
      params[:Name2]    = ''
      params[:Value2]   = ''
      params[:Name3]    = ''
      params[:Value3]   = ''
      1.upto(3) do |n|
        key = keys.shift
        params["Name#{n}".to_sym] = key
        params["Value#{n}".to_sym] = name_values[key]
      end
      params[:apply_to_parent_only] = 'false'
      params[:extension]  = extension
      options.each do |k,v|
        params[k] = v if [:apply_to_parent_only, :extension].include? k
      end
      @tasks << task
    end
  end

  def full_text_extraction( options = {} )
    task              = Hash.new
    task[:task_name]  = 'FullText'
    task[:name]       = 'Full Text Extraction'
    params            = Hash.new
    task[:params]     = params
    params[:Encoding]         = 'UTF-8'
    params[:Extension]         = 'ftx'
    options.each do |k,v|
      params[k] = v if [:Encoding, :Extension].include? k
    end
    @tasks << task
  end

  def write( file )
    doc = create_document

    root = create_node('ingest_settings',
                       :namespaces => {
      :node_ns => 'xb',
      'xb' => 'http://com/exlibris/digitool/common/jobs/xmlbeans' })
    doc.root = root

    node = create_node('transformer_task',
                       :attributes =>{
      'name' => 'Comma separated value (.csv) file',
      'class_name' => 'com.exlibris.digitool.ingest.transformer.valuebased.CsvTransformer'})
    root << node

    node << create_node('param',
                        :attributes => { 'name' => 'template_file', 'value' => 'values.csv' })
    node << create_node('param',
                        :attributes => { 'name' => 'mapping_file', 'value' => 'mapping.xml' })

    i = 0
    chain = create_node('tasks_chain',
                        :attributes => { 'name' => 'Task Chain' })
    @tasks.each do |task|
      chain << write_task(task, i)
      i += 1
    end
    root << chain if i > 0

    root << create_node('ingest_task',
                        :attributes => { 'name' => 'LIAS_ingester' })

    doc.save file, :indent => true

  end

  def write_task( task, nr )

    node = create_node('task_settings',
                       :attributes => {
      'id'        => nr.to_s,
      'task_name' => task[:task_name],
      'name'      => task[:name] })

    TaskParamOrder[task[:task_name]].each do |p|
      param = task[:params][p]
      node << create_node('param',
                          :attributes => { 'name' => p.to_s, 'value' => param.to_s })
    end
    return node
  end

end

