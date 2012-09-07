# coding: utf-8

require_relative 'diff'


def diffrange(a, b)
  if a == b
    "#{a}"
  else
    "#{a},#{b}"
  end
end

class Diff
  def to_diff(io = $stdout)
    offset = 0
    @diffs.each { |b|
      first = b[0][1]
      #length = b.length
      #action = b[0][0]
      addcount = 0
      remcount = 0
      b.each { |l|
        if l[0] == "+"
          addcount += 1
        elsif l[0] == "-"
          remcount += 1
        end
      }
      if addcount == 0
        io.print "#{diffrange(first+1, first+remcount)}d#{first+offset}"
      elsif remcount == 0
        io.print "#{first-offset}a#{diffrange(first+1, first+addcount)}"
      else
        io.print "#{diffrange(first+1, first+remcount)}c#{diffrange(first+offset+1, first+offset+addcount)}"
      end
      lastdel = (b[0][0] == "-")
      b.each { |l|
        if l[0] == "-"
          offset -= 1
          io.print "\n< "
        elsif l[0] == "+"
          offset += 1
          if lastdel
            lastdel = false
            io.print "\n---"
          end
          io.print "\n> "
        end
        io.print l[2]
      }
      io.puts
    }
  end
end
