#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: tablewidget.rb
#  Description: A tabular widget based on textpad
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-03-29 - 20:07
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-03-30 01:32
# ----------------------------------------------------------------------------- #
#   tablewidget.rb  Copyright (C) 2012-2013 rahul kumar

require 'logger'
require 'rbcurse'
require 'rbcurse/core/widgets/textpad'

## 
# The motivation to create yet another table widget is because tabular_widget
# is based on textview etc which have a lot of complex processing and rendering
# whereas textpad is quite simple. It is easy to just add one's own renderer
# making the code base simpler to understand and maintain.
# TODO
#   _ search
#   _ compare to tabular_widget and see what's missing
#   _ sorting
#   _ should we use a datamodel so resultsets can be sent in, what about tabular
#   _ header to handle events ?
#
#
module Lyra
  class ColumnInfo < Struct.new(:name, :width, :align, :hidden)
  end
  # a structure that maintains position and gives
  # next and previous taking max index into account.
  # it also circles. Can be used for traversing next component
  # in a form, or container, or columns in a table.
  class Circular < Struct.new(:max_index, :current_index)
    attr_reader :last_index
    attr_reader :current_index
    def initialize  m, c=0
      raise "max index cannot be nil" unless m
      @max_index = m
      @current_index = c
      @last_index = c
    end
    def next
      @last_index = @current_index
      if @current_index + 1 > @max_index
        @current_index = 0
      else
        @current_index += 1
      end
    end
    def previous
      @last_index = @current_index
      if @current_index - 1 < 0
        @current_index = @max_index
      else
        @current_index -= 1
      end
    end
    def is_last?
      @current_index == @max_index
    end
  end
  #
  # TODO see how jtable does the renderers and columns stuff.
  #
  # perhaps we can combine the two but have different methods or some flag
  # that way oter methods can be shared
  class DefaultTableRenderer
    def initialize
      @y = '|'
      @x = '+'
      @coffsets = []
    end
    def column_model c
      @chash = c
    end
    ##
    # Takes the array of row data and formats it using column widths
    # and returns a string which is used for printing
    #
    def convert_value_to_text r  
      str = ""
      fmt = nil
      r.each_with_index { |e, i| 
        c = @chash[i]
        next if c.hidden
        w = c.width
        l = e.to_s.length
        # if value is longer than width, then truncate it
        if l > w
          fmt = "%.#{w}s "
        else
          case c.align
          when :right
            fmt = "%#{w}s "
          else
            fmt = "%-#{w}s "
          end
        end
        str << fmt % e
      }
      return str
    end
    #
    # @param pad for calling print methods on
    # @param lineno the line number on the pad to print on
    # @param text data to print
    def render pad, lineno, str
      #lineno += 1 # header_adjustment
      return render_header pad, lineno, 0, str if lineno == 0
      bg = :black
      fg = :white
      att = NORMAL
      #cp = $datacolor
      cp = get_color($datacolor, fg, bg)
      #text = str.join " | "
      #text = @fmstr % str
      text = convert_value_to_text str
      FFI::NCurses.wattron(pad,FFI::NCurses.COLOR_PAIR(cp) | att)
      FFI::NCurses.mvwaddstr(pad, lineno, 0, text)
      FFI::NCurses.wattroff(pad,FFI::NCurses.COLOR_PAIR(cp) | att)

    end
    def render_header pad, lineno, col, columns
      #text = columns.join " | "
      #text = @fmstr % columns
      text = convert_value_to_text columns
      bg = :red
      fg = :white
      att = BOLD
      #cp = $datacolor
      cp = get_color($datacolor, fg, bg)
      FFI::NCurses.wattron(pad,FFI::NCurses.COLOR_PAIR(cp) | att)
      FFI::NCurses.mvwaddstr(pad, lineno, col, text)
      FFI::NCurses.wattroff(pad,FFI::NCurses.COLOR_PAIR(cp) | att)
    end
  end

  # If we make a pad of the whole thing then the columns will also go out when scrolling
  # So then there's no point storing columns separately. Might as well keep in content
  # so scrolling works fine, otherwise textpad will have issues scrolling.
  # Making a pad of the content but not column header complicates stuff,
  # do we make a pad of that, or print it like the old thing.
  class TableWidget < TextPad

    dsl_accessor :print_footer
    attr_reader :columns

    def initialize form = nil, config={}, &block

      @chash = {}
      # should be zero here, but then we won't get textpad correct
      @_header_adjustment = 0 #1
      @col_min_width = 3

      super
      bind_key(?w, "next column") { self.next_column }
      bind_key(?b, "prev column") { self.prev_column }
      bind_key(?-, "contract column") { self.contract_column }
      bind_key(?+, "expand column") { self.expand_column }
    end
    def get_column index   #:nodoc:
      return @chash[index] if @chash.has_key? index
      @chash[index] = ColumnInfo.new
    end
    def column_model
      @chash
    end

    # calculate pad width based on widths of columns
    def content_cols
      total = 0
      @chash.each_pair { |i, c| 
        next if c.hidden
        w = c.width
        # if you use prepare_format then use w+2 due to separator symbol
        total += w + 1
      }
      return total
    end
    def calculate_column_offsets
      @coffsets = []
      total = 0

      @chash.each_pair { |i, c| 
        next if c.hidden
        w = c.width
        @coffsets[i] = total
        # if you use prepare_format then use w+2 due to separator symbol
        total += w + 1
      }
    end
    # Convert current cursor position to a table column
    # calculate column based on curpos since user may not have
    # user w and b keys (:next_column)
    # @return [Fixnum] column index base 0
    def _convert_curpos_to_column  #:nodoc:
      calculate_column_offsets unless @coffsets
      x = 0
      #curpos = @tp.curpos
      @coffsets.each_with_index { |i, ix| 
        if @curpos < i 
          break
        else 
          x += 1
        end
      }
      x -= 1 # since we start offsets with 0, so first auto becoming 1
      return x
    end
    def next_column
      # TODO take care of multipliers
      calculate_column_offsets unless @coffsets
      c = @column_pointer.next
      cp = @coffsets[c] 
      $log.debug " next_column #{c} , #{cp} "
      @curpos = cp if cp
      down() if c < @column_pointer.last_index
    end
    def prev_column
      # TODO take care of multipliers
      calculate_column_offsets unless @coffsets
      c = @column_pointer.previous
      cp = @coffsets[c] 
      $log.debug " prev #{c} , #{cp} "
      @curpos = cp if cp
      up() if c > @column_pointer.last_index
    end
    def expand_column
      x = _convert_curpos_to_column
      w = get_column(x).width
      column_width x, w+1 if w
      @coffsets = nil
      fire_dimension_changed
    end
    def contract_column
      x = _convert_curpos_to_column
      w = get_column(x).width 
      return if w <= @col_min_width
      column_width x, w-1 if w
      @coffsets = nil
      fire_dimension_changed
    end

    #def method_missing(name, *args)
    #@tp.send(name, *args)
    #end
    #
    # supply a custom renderer that implements +render()+
    # @see render
    def renderer r
      @renderer = r
    end
    def columns=(array)
      @_header_adjustment = 1
      @columns = array
      @content ||= []
      @content << array
      @columns.each_with_index { |c,i| 
        # if columns added later we could be overwriting the width
        get_column(i).width = 10
      }
      # maintains index in current pointer and gives next or prev
      @column_pointer = Circular.new @columns.size()-1
    end
    alias :headings= :columns=

    def add array
      @content ||= []
      @content << array
      fire_dimension_changed
      self
    end
    def delete ix
      return unless @content
      fire_dimension_changed
      @content.delete_at ix
    end
    alias :<< :add
    def column_width colindex, width
      get_column(colindex).width = width
    end
    def column_align colindex, align
      #@calign[colindex] = width
      get_column(colindex).align = align
    end
    def column_hidden colindex, hidden
      get_column(colindex).hidden = hidden
    end
    def calculate_column_width col, maxrows=99
      ret = 3
      ctr = 0
      @content.each_with_index { |r, i| 
        #next if i < @toprow # this is also a possibility, it checks visible rows
        break if ctr > maxrows
        ctr += 1
        #next if r == :separator
        c = r[col]
        x = c.to_s.length
        ret = x if x > ret
      }
      ret
    end
    ##
    # refresh pad onto window
    # overrides super
    def padrefresh
      top = @window.top
      left = @window.left
      sr = @startrow + top
      sc = @startcol + left
      # first do header always in first row
      retval = FFI::NCurses.prefresh(@pad,0,@pcol, sr , sc , 2 , @cols+ sc );
      # now print rest of data
      # h is header_adjustment
      h = 1 
      retval = FFI::NCurses.prefresh(@pad,@prow + h,@pcol, sr + h , sc , @rows + sr  , @cols+ sc );
      $log.warn "XXX:  PADREFRESH #{retval}, #{@prow}, #{@pcol}, #{sr}, #{sc}, #{@rows+sr}, #{@cols+sc}." if retval == -1
      # padrefresh can fail if width is greater than NCurses.COLS
    end
  end
end
