require 'rubygems'

require 'test/unit'

$: << File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'lib/tools/dc_element'
require 'lib/libis/record_factory'

require 'lib/webservices/ca_search'
require 'lib/webservices/ca_item_info'
