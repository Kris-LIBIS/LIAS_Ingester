# coding: utf-8

require 'tools/assert'

class VarField

  attr_reader :tag
  attr_reader :ind1
  attr_reader :ind2
  attr_reader :subfield

  def initialize(tag, ind1, ind2, subfield)
    @tag = tag
    @ind1 = ind1 || ' '
    @ind2 = ind2 || ' '
    @subfield = subfield || []
  end

  # @return [String] debug output to inspect the contents of the VarField
  def dump
    output = "#@tag:#@ind1:#@ind2:\n"
    @subfield.each { |s, t| output += "\t#{s}:#{t}\n" }
    output
  end

  # @return [String] debug output to inspect the contents of the VarField - Single line version
  def dump_line
    output = "#@tag:#@ind1:#@ind2:"
    @subfield.each { |s, t| output += "$#{s}#{t}" }
    output
  end

  # @return [Array] a list of all subfield cides
  def keys
    @subfield.keys
  end

  # @return [Array] all the entries of a repeatable subfield
  # @param s [Character] the subfield code
  def field_array(s)
    assert(s.is_a?(String) && (s =~ /^[\da-z]$/) == 0, 'method expects a lower case alphanumerical char')
    @subfield.has_key?(s) ? @subfield[s].dup : []
  end

  # @return [String] the first or only entry of a subfield
  # @param s [Character] the subfield code
  def field(s)
    field_array(s).first
  end

  # @return [Array] list of the first or only entries of all subfield codes in the input string
  # @param s [String] string containing the list of subfield codes
  # Note: the subfield codes are <b>not</b> cleaned first
  def fields(s)
    s.split('').collect { |i| self.field(i) }.flatten.compact
  end

  # @return [Array] list of the all the entries of all subfield codes in the input string
  # the subfield codes are cleaned first (see fieldspec_to_array)
  # @param s [String] subfield code specification
  def fields_array(s)
    assert(s.is_a?(String), 'method expects a string')
    fieldspec_to_array(s).collect { |i| self.field_array(i) }.flatten.compact
  end

  # @return [Boolean] does the subfield codes match the given specification?
  # @param fieldspec [String] field specification: sequence of alternative set of subfield codes that should-shouldn't be present
  # The fieldspec consists of groups of characters. At least one of these groups should match for the test to succeed
  # Within the group sets of codes may be divided by a hyphen (-). The first set of codes must all be present;
  # the second set of codes must all <b>not</b> be present. Either set may be empty.
  def match_fieldspec?(fieldspec)
    return true if fieldspec.empty?
    fieldspec.split.each { |f|
      f = f.split '-'
      assert(f.size <= 2, 'more than one "-" is not allowed in a fieldspec')
      must_match = (f[0] || '').split ''
      must_not_match = (f[1] || '').split ''
      return true if (must_match == (must_match & keys)) && (must_not_match & keys).empty?
    }
    false
  end

  private

  # @return [Array] cleaned up version of the input string
  # @param fieldspec [String] subfield code specification
  # cleans the subfield code specification and splits it into an array of characters
  # The array will be sorted (a-z0-9) and duplicates will be removed.
  def fieldspec_to_array(fieldspec)
    # note that we remove
    fieldspec.gsub(/ |-\w*/,'').split('').sort {|x,y| sort_helper(x) <=> sort_helper(y) }
  end

  def sort_helper(x)
    # make sure that everything below 'A' is higher than 'z'
    # note that this only works for numbers, but that is fine in our case.
    x < 'A' ? (x.to_i + 123).chr : x
  end

  def method_missing(name, *args, &block)
    operation, subfields = name.to_s.split('_')
    assert(subfields.size > 0, 'need to specify at least one subfield')
    operation = 'f' if operation.empty?
    case operation
      when 'f'
        if subfields.size > 1
          operation = :fields
        else
          operation = :field
        end
      when 'a'
        if subfields.size > 1
          operation = :fields_array
        else
          operation = :field_array
        end
      else
        throw "Unknown method invocation: '#{name}' with: #{args}"
    end
    send(operation, subfields, block)
  end

  def to_ary
    nil
  end

end
