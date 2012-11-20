# coding: utf-8

require 'singleton'

require 'webservices/soap_client'

#noinspection RubyStringKeysInHashInspection
class DigitalEntityManager
  include Singleton
  include SoapClient

  def initialize
    setup "DigitalEntityManager"
  end
  
  def create_object( de_info )
    de_call = create_digital_entity_call de_info, 'create'
    request :digital_entity_call, :general => general.to_s, :digital_entity_call => de_call.to_s 
  end

  def update_object( de_info, update_options = {} )
    de_call = create_digital_entity_call de_info, 'update', update_options
    request :digital_entity_call, :general => general.to_s, :digital_entity_call => de_call.to_s
  end

  def delete_object( pid )
    de_info = { 'pid' => pid }
    de_options = { 'metadata' => 'all', 'relation' => 'all' }
    de_call1 = create_digital_entity_call de_info, 'update', de_options
    result = request :digital_entity_call, :general => general.to_s, :digital_entity_call => de_call1.to_s
    return result if result[:error] and result[:error].size > 0
    de_call2 = create_digital_entity_call de_info, 'delete'
    request :digital_entity_call, :general => general.to_s, :digital_entity_call => de_call2.to_s
  end

  def retrieve_object( pid )
    de_info = { 'pid' => pid }
    de_call = create_digital_entity_call de_info, 'retrieve'
    request :digital_entity_call, :general => general.to_s, :digital_entity_call => de_call.to_s
  end

  def link_dc(pid, mid)
    link_md pid, mid, 'descriptive', 'dc'
  end

  def unlink_dc(pid,mid)
    unlink_md pid, mid, 'descriptive', 'dc'
  end
  
  def unlink_all_dc(pid)
    unlink_all_md pid, 'descriptive', 'dc'
  end

  def link_acl(pid,mid)
    link_md pid, mid, 'accessrights', 'rights_md'
  end

  def unlink_acl(pid,mid)
    unlink_md pid, mid, 'accessrights', 'rights_md'
  end
  
  def unlink_all_acl(pid)
    unlink_all_md pid, 'accessrights', 'rights_md'
  end

  def link_md(pid, mid, md_name, md_type)
    update_object( { 'pid' => pid.to_s,
                     'metadata' =>
                         [ { 'cmd' => 'insert',
                             'link_to_exists' => 'true',
                             'mid' => mid.to_s,
                             'name' => md_name,
                             'type' => md_type
                           }
                         ]
                   },
                   { 'metadata' => 'delta' }
    )
  end

  def unlink_md(pid, mid, md_name, md_type)
    update_object( { 'pid' => pid.to_s,
                     'metadata' =>
                         [ { 'cmd' => 'delete',
                             'shared' => 'true',
                             'mid' => mid.to_s,
                             'name' => md_name,
                             'type' => md_type
                           }
                         ]
                   },
                   { 'metadata' => 'delta' }
    )
  end
  
  def unlink_all_md(pid, md_name = nil, md_type = nil)
    de_info = { 'pid' => pid.to_s,
                'metadata' =>
                    [ { 'cmd' => 'delete',
                        'shared' => 'true'
                      }
                    ]
    }
    de_info['metadata'][0]['name'] = md_name if md_name
    de_info['metadata'][0]['type'] = md_type if md_type
    update_object( de_info, { 'metadata' => 'all' } )
  end

  def add_relations(pid, relation_type, related_pids)
    relations = []
    related_pids.each do |p|
      relations << { 'cmd' => 'insert',
                     'type' => relation_type.to_s,
                     'pid' => p.to_s
      }
    end
    update_object( { 'pid' => pid.to_s,
                     'relation' => relations
                   },
                   { 'relation' => 'delta' }
    )
  end

  def update_stream(pid, filename)
    update_object( { 'pid' => pid,
                     'stream_ref' =>
                         { 'cmd' => 'update',
                           'store_command' => 'copy',
                           'location' => 'nfs',
                           'file_name' => filename
                         }
                   }
    )
  end

  private

  def create_digital_entity_call( de_info = {}, command = 'create', update_options = {} )
    # de_info is a hash like this:
    # { 'vpid' => 0, || 'pid' => 0,
    #   'control' => { 'label' => 'abc', 'usage_type' => 'archive' },
    #   'metadata' => [ { 'name' => 'descriptive', 'type' => 'dc', 'value' => '<record>...</record>'},
    #                   { 'cmd' => 'insert', 'link_to_exists' => true, 'mid' => '12345' } ],
    #   'relation' => [ { 'cmd' => 'update', 'type' => 'manifestation', 'pid' => '12345' },
    #                   { 'cmd' => 'delete', 'type' => 'part_of', pid => '12345' } ],
    #   'stream_ref' => { 'file_name' => 'abc.tif', 'file_extension' => 'tif', ... }
    # }
    # update_options is something like this:
    # { 'metadata' => 'delta',
    #   'relation' => 'all',
    # }
    digital_entity_call = XmlDocument.new
    root = digital_entity_call.create_node('digital_entity_call',
                                           :namespaces => { :node_ns  => 'xb',
                                                            'xb'      => 'http://com/exlibris/digitool/repository/api/xmlbeans'})
    digital_entity_call.root = root

    root << (digital_entity = digital_entity_call.create_node('xb:digital_entity'))
    digital_entity << digital_entity_call.create_text_node('pid', de_info['pid']) if de_info['pid']
    digital_entity << digital_entity_call.create_text_node('vpid', de_info['vpid']) if de_info['vpid']
    if de_info['control']
      digital_entity << (ctrl = digital_entity_call.create_node('control'))
      de_info['control'].each { |k,v| ctrl << digital_entity_call.create_text_node(k.to_s, v.to_s) }
    end
    if de_info['metadata'] || update_options['metadata']
      attributes = {}
      if (cmd = update_options.delete 'metadata')
        attributes['cmd'] = 'delete_and_insert_' + cmd
      end
      digital_entity << (mds = digital_entity_call.create_node('mds', :attributes => attributes))
      if de_info['metadata']
        de_info['metadata'].each do |m|
          attributes = {}
          if (shared = m.delete 'shared')
            attributes['shared'] = shared
          end
          if (cmd = m.delete 'cmd')
            attributes['cmd'] = cmd
          end
          if (link_to_exists = m.delete 'link_to_exists')
            attributes['link_to_exists'] = link_to_exists
          end
          mds << (md = digital_entity_call.create_node('md', :attributes => attributes))
          m.each { |k,v| md << digital_entity_call.create_text_node(k.to_s, v.to_s) }
        end
      end
    end
    if de_info['relation'] || update_options['relation']
      attributes = {}
      if (cmd = update_options.delete 'relation')
        attributes['cmd'] = 'delete_and_insert_' + cmd
      end
      digital_entity << (relations = digital_entity_call.create_node('relations', :attributes => attributes))
      if de_info['relation']
        de_info['relation'].each do |r|
          attributes = {}
          if (cmd = r.delete 'cmd')
            attributes['cmd'] = cmd
          end
          relations << (relation = digital_entity_call.create_node('relation', :attributes => attributes))
          r.each { |k,v| relation << digital_entity_call.create_text_node(k.to_s, v.to_s) }
        end
      end
    end
    if (f = de_info['stream_ref'])
      attributes = {}
      if (cmd = f.delete 'cmd')
        attributes['cmd'] = cmd
      end
      if (store_command = f.delete 'store_command')
        attributes['store_command'] = store_command
      end
      if (location = f.delete 'location')
        attributes['location'] = location
      end
      digital_entity << (stream_ref = digital_entity_call.create_node('stream_ref', :attributes => attributes))
      de_info['stream_ref'].each { |k,v| stream_ref << digital_entity_call.create_text_node(k.to_s, v.to_s) }
    end
    root << digital_entity_call.create_text_node('command', command)
    digital_entity_call.document
  end

end

