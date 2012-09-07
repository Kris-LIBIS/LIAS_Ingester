# coding: utf-8

#noinspection RubyResolve
require 'set'
require 'cgi'

require 'tools/xml_document'
require 'tools/dc_element'
require 'tools/assert'

require_relative 'fix_field'
require_relative 'var_field'

class MarcRecord

  public

  def initialize(xml_node)
    @node = xml_node
  end

  def to_raw
    @node
  end

  def tag(t, subfields = '')
    tag = t[0..2]
    ind1 = t[3]
    ind2 = t[4]
    get(tag, ind1, ind2, subfields)
  end

  def each_field(t, s)
    tag(t, s).collect { |tag| tag.fields(s) }.flatten.compact
  end

  def first_field(t, s)
    each_field(t, s).first
  end

  def all_fields(t, s)
    tag(t, s).collect { |tag| tag.fields_array(s) }.flatten.compact
  end

  def each
    all.each do |k, v|
      yield k, v
    end
  end

  def all
    return @all_records if @all_records
    @all_records = get_all_records
  end

  def get(tag, ind1 = '', ind2 = '', subfields = '')

    ind1 ||= ''
    ind2 ||= ''
    subfields ||= ''

    ind1.tr!('_', ' ')
    ind1.tr!('#', '')

    ind2.tr!('_', ' ')
    ind2.tr!('#', '')

    record = all[tag]
    return record if record[0].is_a? FixField

    record.select do |v|
      (ind1.empty? or v.ind1 == ind1) && (ind2.empty? or v.ind2 == ind2) && v.match_fieldspec?(subfields)
    end

  end

  #noinspection RubyStringKeysInHashInspection,RubyResolve
  def to_dc(label = nil)

    doc = XmlDocument.new.build do |xml|
      xml.record('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                 'xmlns:dc' => 'http://purl.org/dc/elements/1.1/',
                 'xmlns:dcterms' => 'http://purl.org/dc/terms/') {

        # DC:IDENTIFIER

        xml['dc'].identifier label if label

        # "urn:ControlNumber:" [MARC 001]
        tag('001').each { |t|
          xml['dc'].identifier element(t.datas, prefix: 'urn:ControlNumber:')
        }

        # [MARC 035__ $a]
        each_field('035__', 'a').each { |f| xml['dc'].identifier f }

        # [MARC 24 8_ $a]
        each_field('0248_', 'a').each { |f| xml['dc'].identifier f }

        # [MARC 28 40 $b]": "[MARC 28 40 $a]
        tag('02840').each { |t|
          xml['dc'].identifier element(t._ba, join: ': ')
        }

        # [MARC 28 50 $b]": "[MARC 28 50 $a]
        tag('02850').each { |t|
          xml['dc'].identifier element(t._ba, join: ': ')
        }

        # "Siglum: " [MARC 029 __ $a]
        each_field('029__', 'a').each { |f| xml['dc'].identifier element(f, prefix: 'Siglum: ') }

        # [MARC 700 #_ $0]
        each_field('700#_', '0').each { |f| xml['dc'].identifier f }

        # [MARC 710 #_ $0]
        each_field('710#_', '0').each { |f| xml['dc'].identifier f }

        # [MARC 752 __ $0]
        each_field('752#_', '0').each { |f| xml['dc'].identifier f }

        # "urn:ISBN:"[MARC 020 __ $a]
        each_field('020__', 'a').each { |f|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(f, prefix: 'urn:ISBN:')
        }

        # "urn:ISBN:"[MARC 020 9_ $a]
        each_field('0209_', 'a').each { |f|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(f, prefix: 'urn:ISBN:')
        }

        # "urn:ISSN:"[MARC 022 __ $a]
        each_field('022__', 'a').each { |f|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(f, prefix: 'urn:ISSN:')
        }

        # "urn:ISMN:"[MARC 024 2_ $a]
        each_field('0242_', 'a').each { |f|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(f, prefix: 'urn:ISMN:')
        }

        # "urn:EAN:"[MARC 024 3_ $a]
        each_field('0243_', 'a').each { |f|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(f, prefix: 'urn:EAN:')
        }

        # [MARC 690 02 $0]
        tag('69002', '0a').each { |t|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(odis_link(t._0), CGI::escape(t._a), join: '#')
        }

        # [MARC 856 _2 $u]
        tag('856_2', 'uy').each { |t|
          xml['dc'].identifier('xsi:type' => 'dcterms:URI').text element(t._u, CGI::escape(t._y), join: '#')
        }

        # DC:TITLE

        # [MARC 245 0# $a] " " [MARC 245 0# $b] " [" [MARC 245 0# $h] "]"
        tag('2450#', 'a b h').each { |t|
          xml['dc'].title list(t._ab, opt_s(t._h))
        }

        # [MARC 245 1# $a] " " [MARC 245 1# $b] " [" [MARC 245 1# $h] "]"
        tag('2451#', 'a b h').each { |t|
          xml['dc'].title element(t._ab, opt_s(t._h), join: ' ')
        }

        # [MARC 246 11 $a] " : " [MARC 246 11 $b]
        tag('24611', 'a b').each { |t|
          xml['dc'].title element(t._ab, join: ' : ')
        }

        # DCTERMS:ISPARTOF

        # [MARC 243 1# $a]
        each_field('2431#', 'a').each { |f| xml['dcterms'].isPartOf f }

        # [MARC 440 _# $a] " : " [MARC 440 _# $b] " , " [MARC 440 _# $v]
        tag('440_#', 'a b v').each { |t|
          xml['dcterms'].isPartOf element({parts: t._ab, join: ' : '}, t._v, join: ' , ')
        }

        # [MARC LKR $n]
        each_field('LKR', 'n').each { |f| xml['dcterms'].isPartOf f }

        # [MARC 773 0_ $a] " (" [MARC 773 0_ $g*]")"
        tag('7730_', 'a').each { |t|
          xml['dcterms'].isPartOf element(t._a, opt_r(repeat(t.a_g)), join: ' ')
        }

        # DCTERMS:ALTERNATIVE

        # [MARC 130 #_ $a] ", " [MARC 130 #_ $f] ", " [MARC 130 #_ $g] ", "
        tag('130#_', 'a f g').each { |t|
          xml['dcterms'].alternative element(t._afg, join: ', ', postfix: ', ')
        }

        # [MARC 130 #_ $l] ", " [MARC 130 #_ $m] ", " [MARC 130 #_ $n] ", " [MARC 130 #_ $o] ", " [MARC 130 #_ $p] ", " [MARC 130 #_ $r] ", " [MARC 130 #_ $s]
        tag('130#_', 'l m n o p r s').each { |t|
          xml['dcterms'].alternative element(t._lmnoprs, join: ', ')
        }

        # [MARC 240 1# $a] ", " [MARC 240 1# $f] ", " [MARC 240 1# $g] ", "
        tag('240#_', 'a f g').each { |t|
          xml['dcterms'].alternative element(t._afg, join: ', ', postfix: ', ')
        }

        # [MARC 240 1# $l] ", " [MARC 240 1# $m] ", " [MARC 240 1# $n] ", " [MARC 240 1# $o] ", " [MARC 240 1# $p] ", " [MARC 240 1# $r] ", " [MARC 240 1# $s]
        tag('240#_', 'l m n o p r s').each { |t|
          xml['dcterms'].alternative element(t._lmnoprs, join: ', ')
        }

        # [MARC 242 1# $a] ". " [MARC 242 1# $b]
        tag('2421#', 'a b').each { |t|
          xml['dcterms'].alternative element(t._ab, join: '. ')
        }

        # [MARC 246 13 $a] ". " [MARC 246 13 $b]
        tag('24613', 'a b').each { |t|
          xml['dcterms'].alternative element(t._ab, join: '. ')
        }

        # [MARC 246 19 $a] ". " [MARC 246 19 $b]
        tag('24619', 'a b').each { |t|
          xml['dcterms'].alternative element(t._ab, join: '. ')
        }

        # [MARC 210 10 $a]
        each_field('21010', 'a').each { |f| xml['dcterms'].alternative f }

        # DC:CREATOR

        # [MARC 100 0_ $a] " " [MARC 100 0_ $b] " ("[MARC 100 0_ $c] ") " "("[MARC 100 0_ $d]") ("[MARC 100 0_ $g] "), " [MARC 100 0_ $4]" (" [MARC 100 0_ $9]")"
        tag('1000_', '4').each { |t|
          next unless name_type(t) == :creator
          xml['dc'].creator element(list(t._ab, opt_r(t._c), opt_r(t._d), opt_r(t._g)),
                                    list(full_name(t), opt_r(t._9)),
                                    join: ', ')
        }

        # [MARC 100 1_ $a] " " [MARC 100 1_ $b] " ("[MARC 100 1_ $c] ") " "("[MARC 100 1_ $d]") ("[MARC 100 1_ $g]"), " [MARC 100 1_ $4]" ("[MARC 100 1_ $e]") (" [MARC 100 1_ $9]")"
        tag('1001_', '4').each { |t|
          next unless name_type(t) == :creator
          xml['dc'].creator element(list(t._ab, opt_r(t._c), opt_r(t._d), opt_r(t._g)),
                                    list(full_name(t), opt_r(t._e), opt_r(t._9)),
                                    join: ', ')
        }

        # [MARC 700 0_ $a] ", " [MARC 700 0_ $b] ", " [MARC 700 0_ $c] ", " [MARC 700 0_ $d] ", " [MARC 700 0_ $g] " (" [MARC 700 0_ $4] "), " [MARC 700 0_ $e]
        tag('7000_', '4').each { |t|
          next unless name_type(t) == :creator
          xml['dc'].creator element(t._abcd,
                                    list(t._g, opt_r(full_name(t))),
                                    t._e,
                                    join: ', ')
        }

        # [MARC 700 1_ $a] ", " [MARC 700 1_ $b] ", " [MARC 700 1_ $c] ", " [MARC 700 1_ $d] ", " [MARC 700 1_ $g] " ( " [MARC 700 1_ $4] "), " [MARC 700 1_ $e]
        tag('7001_', '4').each { |t|
          next unless name_type(t) == :creator
          xml['dc'].creator element(t._abcd,
                                    list(t._g, opt_r(full_name(t))),
                                    t._e,
                                    join: ', ')
        }

        # [MARC 710 29 $a] ","  [MARC 710 29 $g]" (" [MARC 710 29 $4] "), " [MARC 710 29 $e]
        tag('71029', '4').each { |t|
          next unless name_type(t) == :creator
          xml['dc'].creator element(t._a,
                                    list(t._g, opt_r(full_name(t))),
                                    t._e,
                                    join: ', ')
        }

        # [MARC 710 2_ $a] " (" [MARC 710 2_ $g] "), " [MARC 710 2_ $4] " (" [MARC 710 2_ $9*] ") ("[MARC 710 2_ $e]")"
        tag('7102_', '4').each { |t|
          next unless name_type(t) == :creator
          xml['dc'].creator element(list(t._a, opt_r(t._g)),
                                    list(full_name(t), opt_r(repeat(t.a_9)), opt_r(t._e)),
                                    join: ', ')
        }

        # [MARC 711 2_ $a] ", "[MARC 711 2_ $n] ", " [MARC 711 2_ $c] ", " [MARC 711 2_ $d] " (" [MARC 711 2_ $g] ")"
        tag('7112_', '4').each { |t|
          next unless name_type(t) == :creator
          xml['dc'].creator element(t._ancd, join: ', ', postfix: opt_r(t._g, prefix: ' '))
        }

        # DC:SUBJECT

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}

        # [MARC 600 #0 $a] " " [MARC 600 #0 $b] " " [MARC 600 #0 $c] " " [MARC 600 #0 $d] " " [MARC 600 #0 $g]
        tag('600#0', 'a b c d g').each { |t|
          xml['dc'].subject(attributes).text list(t._abcdg)
        }

        # [MARC 610 #0 $a] " " [MARC 610 #0 $c] " " [MARC 610 #0 $d] " " [MARC 610 #0 $g]
        tag('610#0', 'a c d g').each { |t|
          xml['dc'].subject(attributes).text list(t._acdg)
        }

        # [MARC 611 #0 $a] " " [MARC 611 #0 $c] " " [MARC 611 #0 $d] " " [MARC 611 #0 $g] " " [MARC 611 #0 $n]
        tag('611#0', 'a c d g n').each { |t|
          xml['dc'].subject(attributes).text list(t._acdgn)
        }

        # [MARC 630 #0 $a] " " [MARC 630 #0 $f] " " [MARC 630 #0 $g] " " [MARC 630 #0 $l] " " [MARC 630 #0 $m] " " [MARC 630 #0 $n] " " [MARC 630 #0 $o] " " [MARC 630 #0 $p] " " [MARC 630 #0 $r] " " [MARC 630 #0 $s]
        tag('630#0', 'a f g l m n o p r s').each { |t|
          xml['dc'].subject(attributes).text list(t._afglmnoprs)
        }

        # [MARC 650 #0 $a] " " [MARC 650 #0 $x] " " [MARC 650 #0 $y] " " [MARC 650 #0 $z]
        tag('650#0', 'a x y z').each { |t|
          xml['dc'].subject(attributes).text list(t._axyz)
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/MESH'}
        # [MARC 650 #2 $a] " " [MARC 650 #2 $x]
        tag('650#2', 'a x').each { |t|
          xml['dc'].subject(attributes).text list(t._ax)
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/UDC'}
        # [MARC 691 E1 $8] " " [ MARC 691 E1 $a]
        tag('691E1', 'a8').each { |t|
          x = taalcode(t._9)
          attributes['xml:lang'] = x if x
          xml['dc'].subject(attributes).text list(t._ax)
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/DDC', 'xml:lang' => 'en'}
        # [MARC 082 14 $a] " " [MARC 082 14 $x]
        tag('08214', 'a x').each { |t|
          xml['dc'].subject(attributes).text list(t._ax)
        }

        # [MARC 690 [xx]$a]
        # Set dedups the fields
        Set.new(each_field('690##', 'a')).each { |f| xml['dc'].subject f }

        # DC:TEMPORAL

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}
        # [MARC 648 #0 $a] " " [MARC 648 #0 $x] " " [MARC 648 #0 $y] " " [MARC 648 #0 $z]
        tag('648#0', 'a x y z').each { |t|
          xml['dc'].temporal(attributes).text list(t._axyz)
        }

        # [MARC 362 __ $a]
        each_field('362__', 'a').each { |f| xml['dc'].temporal f }

        # [MARC 752 9_ $9]
        each_field('7529_', '9').each { |f| xml['dc'].temporal f }

        # [MARC 752 _9 $a] " (" [MARC 752 _9 $9]")"
        tag('752_9', 'a 9').each { |t|
          xml['dc'].temporal list(t._a, opt_r(t._9))
        }

        # DC:DESCRIPTION

        x = element(
            # [MARC 047 __ $a] " (" [MARC 047 __ $9]")"
            tag('047__', 'a 9').collect { |t|
              list(t._a, opt_r(t._9))
            },
            # [MARC 598 __ $a]
            each_field('598__', 'a'),
            # [MARC 597 __ $a]
            each_field('597__', 'a'),
            # [MARC 500 __ $a]
            each_field('500__', 'a'),
            # [MARC 520 2_ $a]
            each_field('5202_', 'a'),
            # "Projectie: " [MARC 093 __ $a]
            tag('093__', 'a').collect { |t| element(t._a, prefix: 'Projectie: ') },
            # "Equidistance " [MARC 094 __ $a*]
            tag('094__', 'a').collect { |t| element(t.a_a, prefix: 'Equidistance ', join: ';') },
            # [MARC 502 __ $a] ([MARC 502 __ $9])
            tag('502__', 'a 9').collect { |t|
              list(t._a, opt(t._9))
            },
            # [MARC 529 __ $a] ", " [MARC 529 __ $b] " (" [MARC 529 __ $c] ")"
            tag('529__', 'a b 9').collect { |t|
              element(t._ab,
                      join: ', ',
                      postfix: opt_r(t._9))
            },
            # [MARC 534 9_ $a]
            each_field('5349_', 'a'),
            # [MARC 534 _9 $a] "(oorspronkelijke uitgever)"
            each_field('534_9', 'a').collect { |f| element(f, postfix: '(oorspronkelijke uitgever)') },
            # [MARC 545 __ $a]
            each_field('545__', 'a'),
            # [MARC 562 __ $a]
            each_field('562__', 'a'),
            # [MARC 563 __ $a] " " [MARC 563 __ $9] " (" [MARC 563 __ $u] ")"
            tag('563__', 'a 9 u').collect { |t|
              list(t._a9, opt_r(t._u))
            },
            # [MARC 586 __ $a]
            each_field('586__', 'a'),
            # [MARC 711 2_ $a] ", " [MARC 711 2_ $n] ", " [MARC 711 2_ $c] ", " [MARC 711 2_ $d] " (" [MARC 711 2_ $g]")"
            tag('7112_', 'a n c d g').collect { |t|
              element(t._ancd,
                      join: ', ',
                      postfix: opt_r(t._g))
            },
            # [MARC 585 __ $a]
            each_field('585__', 'a'),
            join: "\n"
        )
        xml['dc'].description x unless x.empty?

        # DCTERMS:ISVERSIONOF

        # [MARC 250 __ $a] " (" [MARC 250 __ $b] ")"
        tag('250__', 'a b').each { |t|
          xml['dcterms'].isVersionOf list(t._a, opt_r(t._b))
        }

        # DC:ABSTRACT

        # [MARC 520 3_ $a]
        each_field('5203_', 'a').each { |f| xml['dc'].abstract f }

        # [MARC 520 39 $t] ": " [MARC 520 39 $a]
        tag('52039', 'a t').each { |t|
          xml['dc'].abstract element(t._ta, join: ': ')
        }

        # [MARC 520 39 $t] ": " [MARC 520 39 $a]
        tag('52039', 'a t').each { |t|
          attributes = {}
          attributes['xml:lang'] = taalcode(t._9) if t.field_array('9').size == 1
          xml['dc'].abstract(attributes).text element(t._ta, join: ': ')
        }

        attributes = {'xsi:type' => 'dcterms:URI'}
        # [MARC 520 3_ $u]
        all_fields('5203_', 'u').each { |f| xml['dc'].abstract(attributes).text element(f) }

        # [MARC 520 39 $u]
        all_fields('52039', 'u').each { |f| xml['dc'].abstract(attributes).text element(f) }

        # DCTERMS:TABLEOFCONTENTS

        # [MARC 505 0_  $a] " "[MARC 505 0_ $t]" / " [MARC 505 0_ $r*] " ("[MARC 505 0_ $9*]")"
        tag('5050_', 'a t r 9').each { |t|
          xml['dcterms'].tableOfContents list(t._at,
                                              repeat(t.a_r, prefix: '/ '),
                                              opt_r(repeat(t.a_9)))
        }

        # [MARC 505 09 $a*] "\n" [MARC 505 09 $9*] "\n" [MARC 505 09 $u*]
        tag('50509', 'a u 9').each { |t|
          xml['dcterms'].tableOfContents element(repeat(t.a_a),
                                                 repeat(t.a_9),
                                                 repeat(t.a_u),
                                                 join: "\n")
        }

        # [MARC 505 2_  $a] " "[MARC 505 2_ $t]" / " [MARC 505 2_ $r*] " ("[MARC 505 2_ $9*]")"
        tag('5052_', 'a t r 9').each { |t|
          xml['dcterms'].tableOfContents list(t._at,
                                              repeat(t.a_r, prefix: '/ '),
                                              opt_r(repeat(t.a_9)))
        }

        # DCTERMS:AVAILABLE

        # [MARC 591 ## $9] ":" [MARC 591 ## $a] " (" [MARC 591 ## $b] ")"
        tag('591##', 'a b 9').each { |t|
          xml['dcterms'].available element(t._9a, join: ':', postfix: opt_r(t._b, prefix: ' '))
        }

        # DCTERMS:HASPART

        # [MARC LKR $m]
        each_field('LKR', 'm').each { |f| xml['dcterms'].hasPart f }

        # DC:CONTRIBUTOR

        # [MARC 100 0_ $a] " " [MARC 100 0_ $b] " ("[MARC 100 0_ $c] ") (" [MARC 100 0_ $d]") ("[MARC 100 0_ $g]"), " [MARC 100 0_ $4]" (" [MARC 100 0_ $9]")"
        tag('1000_', 'a b c d g 4 9').each { |t|
          next unless name_type(t) == :contributor
          xml['dc'].contributor element(list(t._ab,
                                             opt_r(t._c),
                                             opt_r(t._d),
                                             opt_r(t._g)),
                                        list(full_name(t),
                                             opt_r(t._9)),
                                        join: ', ')
        }

        # [MARC 100 1_ $a] " " [MARC 100 1_ $b] " ("[MARC 100 1_ $c] ") " "("[MARC 100 1_ $d]") ("[MARC 100 1_ $g]"), " [MARC 100 1_ $4]" ("[MARC 100 1_ $e]") (" [MARC 100 1_ $9]")"
        tag('1001_', 'a b c d g 4 e 9').each { |t|
          next unless name_type(t) == :contributor
          xml['dc'].contributor element(list(t._ab,
                                             opt_r(t._c),
                                             opt_r(t._d),
                                             opt_r(t._g)),
                                        list(full_name(t),
                                             opt_r(t._e),
                                             opt_r(t._9)),
                                        join: ', ')
        }

        # [MARC 700 0_ $a] ", " [MARC 700 0_ $b] ", " [MARC 700 0_ $c] ", " [MARC 700 0_ $d] ", " [MARC 700 0_ $g] " ( " [MARC 700 0_ $4] "), " [MARC 700 0_ $e]
        # [MARC 700 1_ $a] ", " [MARC 700 1_ $b] ", " [MARC 700 1_ $c] ", " [MARC 700 1_ $d] ", " [MARC 700 1_ $g] " ( " [MARC 700 1_ $4] "), " [MARC 700 1_ $e]
        (tag('7000_', 'a b c d g 4 e') + tag('7001_', 'a b c d g 4 e')).each { |t|
          next unless name_type(t) == :contributor
          xml['dc'].contributor element(t._abcd,
                                        list(t._g,
                                             opt_r(full_name(t), fix: '( |)')),
                                        t._e,
                                        join: ', ')
        }

        # [MARC 710 29 $a] ","  [MARC 710 29 $g]" (" [MARC 710 29 $4] "), " [MARC 710 29 $e]
        tag('71029', 'a g 4 e').each { |t|
          next unless name_type(t) == :contributor
          xml['dc'].contributor element(t._a,
                                        list(t._g,
                                             opt_r(full_name(t))),
                                        t._e,
                                        join: ', ')
        }

        # [MARC 710 2_ $a] " (" [MARC 710 2_ $g] "), " [MARC 710 2_ $4] " (" [MARC 710 2_ $9] ") ("[MARC 710 2_ $e]")"
        tag('7102_', 'a g 4 9 e').each { |t|
          next unless name_type(t) == :contributor
          xml['dc'].contributor element(list(t._a,
                                             opt_r(t._g)),
                                        list(full_name(t),
                                             opt_r(t._9),
                                             opt_r(t._e)),
                                        join: ', ')
        }

        # [MARC 711 2_ $a] ", "[MARC 711 2_ $n] ", " [MARC 711 2_ $c] ", " [MARC 711 2_ $d] " (" [MARC 711 2_ $g] ")"
        tag('7112_', 'a n c d g').each { |t|
          next unless name_type(t) == :contributor
          xml['dc'].contributor element(t._anc,
                                        list(t._d,
                                             opt_r(t._g)),
                                        join: ', ')
        }

        # DCTERMS:PROVENANCE

        # [MARC 852 __ $b] " " [MARC 852 __ $c]
        tag('852__', 'b c').each { |t|
          xml['dcterms'].provenance list(t._b == t._c ? t._b : t._bc)
        }

        # [MARC 561 ## $a] " " [MARC 561 ## $b] " " [MARC 561 ## $9]
        tag('561##', 'a b 9').each { |t|
          xml['dcterms'].provenance list(t._ab9)
        }

        # DC:PUBLISHER

        # [MARC 260 __ $c] " " [MARC 260 __ $9] " (druk: ) " [MARC 260 __ $g]
        tag('260__', 'c 9 g').each { |t|
          xml['dc'].publisher list(t._c9,
                                   element(t._g, prefix: '(druk: ) '))
        }

        # [MARC 700 0_ $a] ", " [MARC 700 0_ $b] ", " [MARC 700 0_ $c] ", " [MARC 700 0_ $d] ", " [MARC 700 0_ $g] " ( " [MARC 700 0_ $4] "), " [MARC 700 0_ $e] "(uitgever)"
        tag('7000_', 'a b c d e g 4').each { |t|
          next unless name_type(t) == :publisher
          xml['dc'].publisher element(t._abcd,
                                      list(t._g,
                                           opt_r(full_name(t), fix: '( |)')),
                                      t._e,
                                      join: ', ',
                                      postfix: '(uitgever)')
        }

        # [MARC 260 _9 $c] " " [MARC 260 _9 $9*] " (druk: ) " [MARC 260 _9 $g]
        tag('260_9', 'c 9 g').each { |t|
          xml['dc'].publisher list(t._c,
                                   repeat(t.a_9),
                                   element(t._g, prefix: '(druk: ) '))
        }

        # [MARC 710 29 $a] "  (" [MARC 710 29 $c] "), " [MARC 710 29 $9]  ","  [710 29 $g] "(drukker)"
        tag('71029', 'a c g 9 4').each { |t|
          xml['dc'].publisher element(list(t._a,
                                           opt_r(t._c)),
                                      t._9g,
                                      join: ', ',
                                      postfix: '(drukker)')
        }

        # DC:DATE

        # [MARC 008 (07-10)] " - " [MARC 008 (11-14)]
        tag('008').each { |t|
          a = t.datas[7..10].dup
          b = t.datas[11..14].dup
          # return if both parts contained 'uuuu'
          next if a.gsub!(/^uuuu$/, 'xxxx') && b.gsub!(/^uuuu$/, 'xxxx')
          xml['dc'].date element(a, b, join: ' - ')
        }

        # "Datering origineel werk: " [MARC 130 #_ $f]
        tag('130#_', 'f').each { |t|
          xml['dc'].date element(t._f, prefix: 'Datering origineel werk: ')
        }

        # "Datering compositie: " [MARC 240 1# $f]
        tag('2401#', 'f').each { |t|
          xml['dc'].date element(t._f, prefix: 'Datering compositie: ')
        }

        # DC:TYPE

        # [MARC 655 #9 $a]
        each_field('655#9', 'a').each { |f| xml['dc'].type f }

        # [MARC 655 9# $a]
        each_field('6559#', 'a').each { |f| xml['dc'].type f }

        # [MARC 655 _4 $z]
        each_field('655_4', 'z').each { |f| xml['dc'].type f }

        # [MARC FMT]
        tag('FMT').each { |t| xml['dc'].type fmt(t.datas) }

        # [MARC 655 94 $z]
        each_field('65594', 'z').each { |f| xml['dc'].type f }

        # [MARC 655 9_ $a]
        each_field('6559_', 'a').each { |f| xml['dc'].type f }

        # [MARC 088 9_ $a]
        each_field('0889_', 'a').each { |f| xml['dc'].type f } if each_field('088__', 'axy').empty?

        # [MARC 088 __ $z]
        each_field('088__', 'z').each { |f| xml['dc'].type f }

        attributes = {'xml:lang' => 'en'}

        # [MARC 088 __ $a]
        each_field('088__', 'a').each { |f| xml['dc'].type(attributes).text f }

        # [MARC 655 _4 $a]
        each_field('655_4', 'a').each { |f| xml['dc'].type(attributes).text f }

        # [MARC 655 94 $a]
        each_field('65594', 'a').each { |f| xml['dc'].type(attributes).text f }

        attributes = {'xml:lang' => 'nl'}

        # [MARC 088 __ $x]
        each_field('088__', 'x').each { |f| xml['dc'].type(attributes).text f }

        # [MARC 655 _4 $x]
        each_field('655_4', 'x').each { |f| xml['dc'].type(attributes).text f }

        # [MARC 655 94 $x]
        each_field('65594', 'x').each { |f| xml['dc'].type(attributes).text f }

        attributes = {'xml:lang' => 'fr'}

        # [MARC 088 __ $y]
        each_field('088__', 'y').each { |f| xml['dc'].type(attributes).text f }

        # [MARC 655 _4 $y]
        each_field('655_4', 'y').each { |f| xml['dc'].type(attributes).text f }

        # [MARC 655 94 $y]
        each_field('65594', 'y').each { |f| xml['dc'].type(attributes).text f }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/MESH'}

        # [MARC 655 #2 $a] " " [MARC 655 #2 $x*] " " [MARC 655 #2 $9]
        tag('655#2', 'a x 9').each { |t|
          xml['dc'].type(attributes).text list(t._a,
                                               repeat(t.a_x),
                                               t._9)
        }

        # DCTERMS:SPATIAL

        # [MARC 752 __ $a]  " " [MARC 752 __ $c] " " [MARC 752 __ $d] " (" [MARC 752 __ $9] ")"
        tag('752__', 'a c d 9').each { |t|
          xml['dcterms'].spatial list(t._acd,
                                      opt_r(t._9))
        }

        # "Schaal: " [MARC 034 1_ $a]
        each_field('0341_', 'a').each { |f|
          xml['dcterms'].spatial element(f, prefix: 'Schaal: ')
        }

        # "Schaal: " [MARC 034 3_ $a*]
        tag('0343_', 'a').each { |t|
          xml['dcterms'].spatial repeat(t.a_a, prefix: 'Schaal: ')
        }

        # [MARC 034 91 $d] " " [MARC 034 91 $e] " " [MARC 034 91 $f] " " [MARC 034 91 $g]
        tag('03491', 'd e f g').each { |t| xml['dcterms'].spatial list(t._defg) }

        # [MARC 507 __ $a]
        each_field('507__', 'a').each { |f| xml['dcterms'].spatial f }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}

        # [MARC 651 #0 $a] " " [MARC 651 #0 $x*] " " [MARC 651 #0 $y] " " [MARC 651 #0 $z]
        tag('651#0', 'a x y z').each { |t|
          xml['dcterms'].spatial(attributes).text list(t._a,
                                                       repeat(t.a_x),
                                                       t._yz)
        }

        attributes = {'xsi:type' => 'http://purl.org/dc/terms/LCSH'}

        # [MARC 651 #2 $a] " " [MARC 651 #2 $x*]
        tag('651#2', 'a x').each { |t|
          xml['dcterms'].spatial(attributes).text list(t._a,
                                                       repeat(t.a_x))
        }

        # DCTERMS:EXTENT

        # [MARC 300 __ $a*] " " [MARC 300 __ $b] " " [MARC 300__  $c*] " " [MARC 300 __ $e] " (" [MARC 300 __ $9] ")"
        tag('300__', 'a b c e 9').each { |t|
          xml['dcterms'].extent list(repeat(t.a_a),
                                     t._b,
                                     repeat(t.a_c),
                                     t._e,
                                     opt_r(t._9))
        }

        # [MARC 300 9_ $a] " " [MARC 300 9_ $b] " " [MARC 300 9_ $c*] " " [MARC 300 9_ $e] " (" [MARC 300 9_ $9]")"
        tag('3009_', 'a b c e 9').each { |t|
          xml['dcterms'].extent list(t._ab,
                                     repeat(t.a_c),
                                     t._e,
                                     opt_r(t._9))
        }

        # [MARC 300 9_ $a] " " [MARC 300 9_ $b] " " [MARC 300 9_ $c*] " " [MARC 300 9_ $e] " (" [MARC 300 9_ $9]")"
        tag('3009_', 'a b c e 9').each { |t|
          xml['dcterms'].extent list(t._ab,
                                     repeat(t.a_c),
                                     t._e,
                                     opt_r(t._9))
        }

        # [MARC 306 __  $a*]
        tag('306__', 'a').each { |t| xml['dcterms'].extent repeat(t.a_a.collect { |x| x.scan(/(\d\d)(\d\d)(\d\d)/).join(':') }) }

        # [MARC 309 __ $a]
        each_field('309__', 'a').each { |f| xml['dcterms'].extent f }

        # [MARC 339 __ $a*]
        tag('339__', 'a').each { |t| xml['dcterms'].extent repeat(t.a_a) }

        # DCTERMS:ACCRUALPERIODICITY

        # [MARC 310 __ $a] " (" [MARC 310 __ $b] ")"
        tag('310__', 'a b').each { |t|
          xml['dcterms'].accrualPeriodicity list(t._a,
                                                 opt_r(t._b))
        }

        # DC:FORMAT


        # [MARC 340 __ $a*]
        tag('340__', 'a').each { |t|
          xml['dc'].format repeat(t.a_a)
        }

        # [MARC 319 __ $a]
        each_field('319__', 'a').each { |f| xml['dc'].format f }

        # [MARC 319 9_ $a] " (" [MARC 319 9_ $9] ")"
        tag('3199_', 'a 9').each { |t|
          xml['dc'].format list(t._a,
                                opt_r(t._9))
        }

        # DCTERMS:MEDIUM

        # [MARC 399 __ $a]  " " [MARC 399 __ $b] " (" [MARC 399 __ $9] ")"
        tag('399__', 'a b 9').each { |t|
          xml['dcterms'].medium list(t._ab,
                                     opt_r(t._9))
        }

        # DC:RELATION

        # [MARC 580 __ $a]
        each_field('580__', 'a').each { |e| xml['dc'].relation e }

        # DCTERMS:REPLACES

        # [MARC 247 1# $a] " : " [MARC 247 1# $b] " (" [MARC 247 1# $9] ")"
        tag('2471#', 'a b 9').each { |t|
          xml['dcterms'].replaces list(element(t._a, t._b, join: ' : '), opt_r(t._9))
        }

        # DCTERMS:HASVERSION

        # [MARC 534 __ $a]
        each_field('534__', 'a').each { |f| xml['dcterms'].hasVersion f }

        # DC:SOURCE

        # [MARC 852 __ $b] " " [MARC 852 __ $c] " " [MARC 852 __ $k] " " [MARC 852 __ $h] " " [MARC 852 __ $9] " " [MARC 852 __ $l] " " [MARC 852 __ $m]
        tag('852__', 'b c k h 9 l m').each { |t|
          xml['dc'].source list(t._bckh9lm)
        }

        attributes = {'xsi:type' => 'dcterms:URI'}

        # [MARC 856 _1 $u]
        tag('856_1', 'uy').each { |t|
          xml['dc'].source(attributes).text element(t._u,
                                                    repeat(t.a_y.collect { |y| CGI::escape(y) }),
                                                    join: '#')
        }

        # [MARC 856 _2 $u]
        tag('856_2', 'uy').each { |t|
          xml['dc'].source(attributes).text element(t._u,
                                                    repeat(t.a_y.collect { |y| CGI::escape(y) }),
                                                    join: '#')
        }

        # [MARC 856 40 $u]
        tag('8562', 'u').each { |t|
          xml['dc'].source(attributes).text element(t._u)
        }

        # DC:LANGUAGE

        # [MARC 041 9_ $a*]
        tag('0419_', 'a').each { |t|
          xml['dc'].language repeat(t.a_a.collect { |x| taalcode(x) })
        }

        # [MARC 041 9_ $d*]
        tag('0419_', 'd').each { |t|
          xml['dc'].language repeat(t.a_d.collect { |x| taalcode(x) })
        }

        # [MARC 041 9_ $e*]
        tag('0419_', 'e').each { |t|
          xml['dc'].language repeat(t.a_e.collect { |x| taalcode(x) })
        }

        # [MARC 041 9_ $f*]
        tag('0419_', 'f').each { |t|
          xml['dc'].language repeat(t.a_f.collect { |x| taalcode(x) })
        }

        # [MARC 041 9_ $h*]
        tag('0419_', 'h').each { |t|
          xml['dc'].language repeat(t.a_h.collect { |x| taalcode(x) })
        }

        # [MARC 041 9_ $9*]
        tag('0419_', '9').each { |t|
          xml['dc'].language repeat(t.a_9.collect { |x| taalcode(x) })
        }

        # "Gedubde taal: " [MARC 041 _9 $a*]
        tag('041_9', 'a').each { |t|
          xml['dc'].language repeat(t.a_a.collect { |x| taalcode(x) }, prefix: 'Gedubde taal:')
        }

        # [MARC 041 _9 $h*]
        tag('041_9', 'h').each { |t|
          xml['dc'].language repeat(t.a_h.collect { |x| taalcode(x) })
        }

        # "Ondertitels: " [MARC 041 _9 $9*]
        tag('041_9', '9').each { |t|
          xml['dc'].language element(t.a_9.collect { |x| taalcode(x) }, prefix: 'Ondertitels:')
        }

        # [MARC 008 (35-37)]
        tag('008').each { |t|
          xml['dc'].language taalcode(t.datas[35..37])
        } if tag('041').empty?

        # [MARC 130 #_ $l]
        each_field('130#_', 'l').each { |f| xml['dc'].language f }

        # [MARC 240 #_ $l]
        each_field('240#_', 'l').each { |f| xml['dc'].language f }

        # [MARC 546 __ $a]
        each_field('546__', 'a').each { |f| xml['dc'].language f }

        # []MARC 546 9_ $a]
        each_field('5469_', 'a').each { |f| xml['dc'].language f }

        # [MARC 546 _9 $a]
        each_field('546_9', 'a').each { |f| xml['dc'].language f }

        # DCTERMS:RIGHTSHOLDER

        # [MARC 700 0_ $a] ", " [MARC 700 0_ $b] ", " [MARC 700 0_ $c] ", " [MARC 700 0_ $d] ", " [MARC 700 0_ $g] ", " [MARC 700 0_ $e] (als $4 cph)
        tag('7000_', '4').each { |t|
          next unless name_type(t) == :rightsholder
          xml['dcterms'].rightsholder element(t._abcdge, join: ', ')
        }

        # [MARC 710 2_ $a] " (" [MARC 710 2_ $g] "), (" [MARC 710 2_ $9] ") ("[MARC 710 2_ $e]")" (als $4 cph)
        tag('7102_', '4').each { |t|
          next unless name_type(t) == :rightsholder
          xml['dcterms'].rightsholder element(list(t._a,
                                                   opt_r(t._g)),
                                              list(opt_r(t._9),
                                                   opt_r(t._e)),
                                              join: ', ')
        }

        # DCTERMS:REFERENCES

        # [MARC 581 __ $a]
        each_field('581__', 'a').each { |f| xml['dcterms'].references f }

        # DCTERMS:ISREFERENCEDBY

        # [MARC 510 0_ $a] ", " [MARC 510 0_ $c]
        tag('5100_', 'a c').each { |t|
          xml['dcterms'].isReferencedBy element(t._ac, join: ', ')
        }

        # [MARC 510 3_ $a] ", " [MARC 510 3_ $c]
        tag('5103_', 'a c').each { |t|
          xml['dcterms'].isReferencedBy element(t._ac, join: ', ')
        }

        # [MARC 510 4_ $a] ", " [MARC 510 4_ $c]
        tag('5104_', 'a c').each { |t|
          xml['dcterms'].isReferencedBy element(t._ac, join: ', ')
        }

      }
    end

    # deduplicate the XML
    found = Set.new
    doc.root.children.each { |node| node.unlink unless found.add?(node.to_xml) }

    doc

  end

  def to_aseq
    record = ''
    doc_number = tag('001').datas

    all.select { |t| t.is_a? FixField }.each { |t| record += "#{format("%09s",doc_number)} #{t.tag}   L #{t.datas}\n" }
    all.select { |t| t.is_a? VarField}.each { |t|
      record += "#{format("%09s",doc_number)} #{t.tag}#{t.ind1}#{t.ind2} L "
      t.keys.each { |k|
        t.field_array(k).each { |f|
          record += "$$#{k}#{CGI::unescapeHTML(f)}"
        }
      }
      record += "\n"
    }

    record
  end

  def to_oai_pmh
    XmlDocument.new.build do |xml|
      xml.tag!('OAI-PMH',
              "xmlns" => 'http://www.openarchives.org/OAI/2.0/',
              "xmlns:xsi" => 'http://www.w3.org/2001/XMLSchema-instance',
              "xsi:schemaLocation" => 'http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd') {
        xml.tag!('ListRecords') {
          xml.record {
            xml.header {
              xml.identifier("aleph-publish:#{tag('001').first.datas.strip}")
            }
            xml.metadata {
              xml.record("xmlns" => "http://www.loc.gov/MARC21/slim",
                         "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
                         "xsi:schemaLocation" => "http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd") {
                xml.leader tag('LDR').first.datas
                record.all.select { |t| t.is_a? FixField }.each { |t|
                  if t.tag.eql?('FMT')
                    xml.datafield('tag' => t.tag, 'ind1' => ' ', 'ind2' => ' ').text t.datas
                  else
                    xml.controlfield('tag' => t.tag).text t.datas
                  end
                }
                record.all.select { |t| t.is_a? VarField }.each { |t|
                  xml.datafield('tag' => t.tag, 'ind1' => t.ind1, 'ind2' => t.ind2) {
                    t.keys.each { |k|
                      t.field_array(k).each { |v|
                        xml.subfield('code' => k).text v
                      }
                    }
                  }
                }
                xml.datafield('KUL', 'tag' => 'OWN', 'ind1' => '', 'ind2' => '')
                xml.datafield('tag' => 'AVA', 'ind1' => '', 'ind2' => '') {
                  xml.subfield('LBS50', 'code' => 'a')
                  xml.subfield('BIBC', 'code' => 'b')
                  xml.subfield('available', 'code' => 'e')
                }
              }
            }
          }
        }
      }
    end
  end

  def dump
    all.values.flatten.each_with_object([]) { |record, m| m << record.dump }.join
  end

  private

  def dc_element(default_options, *parts)
    DcElement.new(*parts).add_default_options(default_options).to_s
  end

  def element(*parts)
    dc_element({}, *parts)
  end

  def repeat(*parts)
    dc_element({join: ';'}, *parts)
  end

  def list(*parts)
    dc_element({join: ' '}, *parts)
  end

  def opt_r(*parts)
    dc_element({fix: '()'}, *parts)
  end

  def opt_s(*parts)
    dc_element({fix: '[]'}, *parts)
  end

  def odis_link(label)
    case label
      when /\(ODIS-(\w\w)\)(\d*)/
        return "http://www.odis.be/lnk/#{$1.downcase}_#{$2}"
      else
        return label
    end
  end

  def name_type(data)
    #noinspection RubyResolve
    code = data._4.to_sym
    DOLLAR4TABLE[data.tag][code][1]
  end

  def full_name(data)
    #noinspection RubyResolve
    code = data._4.to_sym
    DOLLAR4TABLE[data.tag][code][0]
  end

  def taalcode(code)
    TAALCODES[code.to_sym]
  end

  def bibnaam(code)
    BIBCODES[code] || ''
  end

  def fmt(code)
    FMT[code.to_sym] || ''
  end

  #noinspection RubyStringKeysInHashInspection
  DOLLAR4TABLE = {
      '700' => {
          apb: ['approbation, approbatie, approbation', :contributor],
          apr: ['preface', nil],
          arc: ['architect', :contributor],
          arr: ['arranger', :contributor],
          art: ['artist', :creator],
          aui: ['author of introduction', :contributor],
          aut: ['author', :creator],
          bbl: ['bibliography', :contributor],
          bdd: ['binder', :contributor],
          bsl: ['bookseller', :contributor],
          ccp: ['concept', :contributor],
          chr: ['choreographer', :contributor],
          clb: ['collaborator', :contributor],
          cmm: ['commentator (rare books only)', :contributor],
          cmp: ['composer', :contributor],
          cnd: ['conductor', :contributor],
          cns: ['censor, censeur', :contributor],
          cod: ['co-ordination', :contributor],
          cof: ['collection from', :contributor],
          coi: ['compiler index', :contributor],
          com: ['compiler', :contributor],
          con: ['consultant', :contributor],
          cov: ['cover designer', :contributor],
          cph: ['copyright holder', :rightsholder],
          cre: ['creator', :creator],
          csp: ['project manager', :contributor],
          ctb: ['contributor', :contributor],
          ctg: ['cartographer', :creator],
          cur: ['curator', :contributor],
          dfr: ['defender (rare books only)', :contributor],
          dgg: ['degree grantor', :contributor],
          dir: ['director', :creator],
          dnc: ['dancer', :contributor],
          dpc: ['depicted', :contributor],
          dsr: ['designer', :contributor],
          dte: ['dedicatee', :contributor],
          dub: ['dubious author', :creator],
          eda: ['editor assistant', :contributor],
          edc: ['editor in chief', :creator],
          ede: ['final editing', :creator],
          edt: ['editor', :creator],
          egr: ['engraver', :contributor],
          eim: ['editor of image', :contributor],
          eow: ['editor original work', :contributor],
          etc: ['etcher', :contributor],
          eul: ['eulogist, drempeldichter, panégyriste', :contributor],
          hnr: ['honoree', :contributor],
          ihd: ['expert trainee post (inhoudsdeskundige stageplaats)', :contributor],
          ill: ['illustrator', :contributor],
          ilu: ['illuminator', :contributor],
          itr: ['instrumentalist', :contributor],
          ive: ['interviewee', :contributor],
          ivr: ['interviewer', :contributor],
          lbt: ['librettist', :contributor],
          ltg: ['lithographer', :contributor],
          lyr: ['lyricist', :contributor],
          mus: ['musician', :contributor],
          nrt: ['narrator, reader', :contributor],
          ogz: ['started by', :creator],
          oqz: ['continued by', :creator],
          orc: ['orchestrator', :contributor],
          orm: ['organizer of meeting', :contributor],
          oth: ['other', :contributor],
          pat: ['patron, opdrachtgever, maître d\'oeuvre', :contributor],
          pht: ['photographer', :creator],
          prf: ['performer', :contributor],
          pro: ['producer', :contributor],
          prt: ['printer', :publisher],
          pub: ['publication about', :subject],
          rbr: ['rubricator', :contributor],
          rea: ['realization', :contributor],
          reb: ['revised by', :contributor],
          rev: ['reviewer', :contributor],
          rpt: ['reporter', :contributor],
          rpy: ['responsible party', :contributor],
          sad: ['scientific advice', :contributor],
          sce: ['scenarist', :contributor],
          sco: ['scientific co-operator', :contributor],
          scr: ['scribe', :contributor],
          sng: ['singer', :contributor],
          spn: ['sponsor', :contributor],
          sum: ['summary', :abstract],
          tec: ['technical direction', :contributor],
          thc: ['thesis co-advisor(s)', :contributor],
          thj: ['member of the jury', :contributor],
          ths: ['thesis advisor', :contributor],
          trc: ['transcriber', :contributor],
          trl: ['translator', :contributor],
          udr: ['under direction of', :contributor],
          voc: ['vocalist', :contributor],
      },
      '710' => {
          adq: ['readapted by', :contributor],
          add: ['addressee, bestemmeling', :contributor],
          aow: ['author original work, auteur oorspronkelijk werk, auteur ouvrage original', :contributor],
          apr: ['preface', :/],
          arc: ['architect', :contributor],
          art: ['artist', :creator],
          aut: ['author', :creator],
          bbl: ['bibliography', :contributor],
          bdd: ['binder', :contributor],
          bsl: ['bookseller', :contributor],
          ccp: ['concept', :contributor],
          clb: ['collaborator', :contributor],
          cod: ['co-ordination', :contributor],
          cof: ['collection from', :contributor],
          coi: ['compiler index', :contributor],
          com: ['compiler', :contributor],
          con: ['consultant', :contributor],
          cov: ['cover designer', :contributor],
          cph: ['copyright holder', :rightsholder],
          cre: ['creator', :creator],
          csp: ['project manager', :contributor],
          ctb: ['contributor', :contributor],
          ctg: ['cartographer', :contributor],
          cur: ['curator', :contributor],
          dgg: ['degree grantor', :contributor],
          dnc: ['dancer', :contributor],
          dsr: ['designer', :contributor],
          dte: ['dedicatee', :contributor],
          eda: ['editor assistant', :contributor],
          edc: ['editor in chief', :creator],
          ede: ['final editing', :creator],
          edt: ['editor', :creator],
          egr: ['engraver', :contributor],
          eim: ['editor of image', :contributor],
          eow: ['editor original work', :contributor],
          etc: ['etcher', :contributor],
          eul: ['eulogist, drempeldichter, panégyriste', :contributor],
          hnr: ['honoree', :contributor],
          itr: ['instrumentalist', :contributor],
          ltg: ['lithographer', :contributor],
          mus: ['musician', :contributor],
          ogz: ['started by', :creator],
          oqz: ['continued by', :creator],
          ori: ['org. institute (rare books/mss only)', :contributor],
          orm: ['organizer of meeting', :contributor],
          oth: ['other', :contributor],
          pat: ['patron', :contributor],
          pht: ['photographer', :creator],
          prf: ['performer', :contributor],
          pro: ['producer', :contributor],
          prt: ['printer', :publisher],
          pub: ['publication about', :subject],
          rea: ['realization', :contributor],
          rpt: ['reporter', :contributor],
          rpy: ['responsible party', :contributor],
          sad: ['scientific advice', :contributor],
          sco: ['scientific co-operator', :contributor],
          scp: ['scriptorium', :contributor],
          sng: ['singer', :contributor],
          spn: ['sponsor', :contributor],
          sum: ['summary', :abstract],
          tec: ['technical direction', :contributor],
          trc: ['transcriber', :contributor],
          trl: ['translator', :contributor],
          udr: ['under direction of', :contributor],
          voc: ['vocalist', :contributor],
      },
      '711' => {
          oth: ['other', :contributor],
      },
      '100' => {
          arr: ['arranger', :contributor],
          aut: ['author', :creator],
          cmp: ['composer', :contributor],
          com: ['compiler', :contributor],
          cre: ['creator', :creator],
          ctg: ['cartographer', :creator],
          ill: ['illustrator', :contributor],
          ivr: ['interviewer', :contributor],
          lbt: ['librettist', :contributor],
          lyr: ['lyricist', :contributor],
          pht: ['photographer', :creator],
      }
  }

  TAALCODES = {
      afr: 'af',
      ara: 'ar',
      chi: 'zh',
      cze: 'cs',
      dan: 'da',
      dum: 'dum',
      dut: 'nl',
      est: 'et',
      eng: 'en',
      fin: 'fi',
      fre: 'fr',
      frm: 'frm',
      ger: 'de',
      grc: 'grc',
      gre: 'el',
      hun: 'hu',
      fry: 'fy',
      ita: 'it',
      jpn: 'ja',
      lat: 'la',
      lav: 'lv',
      liv: 'lt',
      ltz: 'lb',
      mlt: 'mt',
      nor: 'no',
      pol: 'pl',
      por: 'pt',
      rus: 'ru',
      slo: 'sk',
      slv: 'sl',
      spa: 'es',
      swe: 'sv',
      tur: 'tr',
      ukr: 'uk',
  }

  #noinspection RubyStringKeysInHashInspection
  BIBCODES = {
      '01' => 'K.U.Leuven',
      '02' => 'KADOC',
      '03' => 'BB(Boerenbond)/KBC',
      '04' => 'HUB',
      '05' => 'ACV',
      '06' => 'LIBAR',
      '07' => 'SHARE',
      '10' => 'BPB',
      '11' => 'VLP',
      '12' => 'TIFA',
      '13' => 'LESSIUS',
      '14' => 'SERV',
      '15' => 'ACBE',
      '16' => 'SLUCB',
      '17' => 'SLUCG',
      '18' => 'HUB',
      '19' => 'KHBO',
      '20' => 'FINBI',
      '21' => 'BIOET',
      '22' => 'LUKAS',
      '23' => 'KHM',
      '24' => 'Fonds',
      '25' => 'RBINS',
      '26' => 'RMCA',
      '27' => 'NBB',
      '28' => 'Pasteurinstituut',
      '29' => 'Vesalius',
      '30' => 'Lemmensinstituut',
      '31' => 'KHLIM',
      '32' => 'KATHO',
      '33' => 'KAHO',
      '34' => 'HUB',
  }

  FMT = {
      BK: 'Books',
      SE: 'Continuing Resources',
      MU: 'Music',
      MP: 'Maps',
      VM: 'Visual Materials',
      AM: 'Audio Materials',
      CF: 'Computer Files',
      MX: 'Mixed Materials',
  }

end
