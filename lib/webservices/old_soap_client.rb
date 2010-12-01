require 'soap/rpc/driver'
require 'tools/xml_writer'

class OldSoapClient
  include XmlWriter

  attr_reader :client

  def initialize( service )
    url = "http://aleph08.libis.kuleuven.be:1801/de_repository_web/services/" + service
    @client = SOAP::RPC::Driver.new url
    @client.generate_explicit_type = false
  end

  def parse_result( result )
    error = []
    result.scan(/<error_description>([^<]+)<\/error_description>/) { |x| error << x }
    pids = []
    result.scan(/<pid>(\d+)<\/pid>/) { |x| pids << x }
    mids = []
    result.scan(/<mid>(\d+)<\/mid>/) { |x| mids << x }
    de = []
    result.scan(/(<xb:digital_entity>.*?<\/xb:digital_entity>)/x) { |x| de << x }
    { :error => error, :pids => pids, :mids => mids, :digital_entities => de, :result => result}
  end

  def general( owner = 'LIA01', user = 'super:lia01', password = 'super' )
    doc = create_document
    root = create_node('general',
                       :namespaces => { :node_ns   => 'xb',
                                        'xb'       => 'http://com/exlibris/digitool/repository/api/xmlbeans'})
    doc.root = root
    root << (create_node('application') << 'DIGITOOL-3')
    root << (create_node('owner') << owner)
    root << (create_node('interface_version') << '1.0')
    root << (create_node('user') << user)
    root << (create_node('password') << password)
    return doc
  end

end

