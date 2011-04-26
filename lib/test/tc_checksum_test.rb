require "test/unit"

require_relative '../tools/checksum'

class ChecksumTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_initialize
    cs = Checksum.new(:MD5)
    assert_equal(:MD5, cs.type)
  end
  # Fake test
  def test_fail

    # To change this template use File | Settings | File Templates.
    fail("Not implemented")
  end
end