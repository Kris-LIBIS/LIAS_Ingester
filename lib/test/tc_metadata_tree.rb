# coding: utf-8

require 'test/unit'

$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'tools/sharepoint_metadata_tree'

class TestMetadataTree < MiniTest::Unit::TestCase
  
  def test_add
    tree = SharepointMetadataTree.new nil
    a = SharepointRecord.new
    a_node = tree.add a
    assert_nil(a_node)
    a[:ows_FileRef] = 'sites/lias/Gedeelde documenten/A/B/C/D.doc'
    a_node = tree.add a
    refute_nil(a_node)
    assert_equal(a_node, a.node)
  end
  
  def test_get
    tree = SharepointMetadataTree.new nil
    node = tree.get('A/B')
    refute_nil(node)
    assert_nil(node.content)
    node = tree['A']
    refute_nil(node)
    assert_equal(node,tree.get('A'))
    assert_nil(node.content)
  end

  def test_lookup
    tree = SharepointMetadataTree.new nil
    a = SharepointRecord.new
    a[:ows_FileRef] = 'sites/lias/Gedeelde documenten/X/Y/Z/A.doc'
    a[:ows_ContentType] = 'Bestanddeel of stuk (document)'
    a_node = tree.add a
    node = tree['A/B/C']
    assert_nil(node)
    node = tree['X/Y']
    refute_nil(node, 'Node not found')
    assert_equal(node.name,'Y')
    assert_nil(node.content)
    node = tree['X/Y/Z/A.doc']
    refute_nil(node)
    refute_nil(node.content)
    assert_equal(node.name,'A.doc')
    assert_equal(node,a_node)
    refute_nil(node.content)
    assert_equal(a,node.content)
    node_parent = tree['X/Y/Z']
    assert_equal(node_parent,a_node.parent)
  end

  def test_file_path
    tree = SharepointMetadataTree.new nil
    a = SharepointRecord.new
    a[:ows_FileRef] = 'sites/lias/Gedeelde documenten/X/Y/Z/A.doc'
    a[:ows_ContentType] = 'Bestanddeel of stuk (document)'
    a_node = tree.add a
    b = SharepointRecord.new
    b[:ows_FileRef] = 'sites/lias/Gedeelde documenten/X/Y/A/B.doc'
    b_node = tree.add b
    assert_nil(tree.file_path(nil, nil))
    assert_equal('X/Y/Z/A.doc',tree.file_path(a_node, nil))
    assert_equal('X/Y/A/B.doc',tree.file_path(b_node, nil))
    node = tree['X/Y']
    assert_equal('Z/A.doc',tree.file_path(a_node,node))
    assert_equal('A/B.doc',tree.file_path(b_node,node))
    node = tree['X/Y/Z']
    assert_equal('A.doc',tree.file_path(a_node,a_node))
    assert_equal('A.doc',tree.file_path(a_node,node))
    assert_equal('../A/B.doc',tree.file_path(b_node,node))
    assert_equal('../A/B.doc',tree.file_path(b_node,a_node))
  end

end
