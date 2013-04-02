#!/usr/bin/env ruby

require 'logger'
require 'rbcurse'
require 'lyra/tablewidget'
#

def edit_row tw
  row = tw.current_value
  h   = tw.columns
  _edit h, row, " Edit "
  tw.fire_row_changed tw.current_index
end
def insert_row tw
  h   = tw.columns
  row = []
  h.each { |e| row << "" }
  ret = _edit h, row, "Insert"
  if ret
    tw.add row
    tw.fire_dimension_changed
  end
end

# making a generic edit messagebox - quick dirty
def _edit h, row, title
  _l = longest_in_list h
  _w = _l.size
  # _w can be longer than 70, assuming that screen is 70 or more
  config = { :width => 70, :title => title }
  bw = get_color $datacolor, :black, :white
  mb = MessageBox.new config do
    txt = nil
    h.each_with_index { |f, i| 
      txt = row[i] || ""
      add Field.new :label => "%*s:" % [_w, f], :text => txt.chomp, :name => i.to_s, 
        :bgcolor => :cyan,
        :display_length => 50,
        :label_color_pair => bw
    }
    button_type :ok_cancel
  end
  index = mb.run
  return nil if index != 0
  h.each_with_index { |e, i| 
    f = mb.widget(i.to_s)
    row[i] = f.text
  }
  row
end
begin
  # Initialize curses
  VER::start_ncurses  # this is initializing colors via ColorMap.setup
  path = File.join(ENV["LOGDIR"] || "./" ,"r.log")
  logfilename   = File.open(path, File::WRONLY|File::TRUNC|File::CREAT) 
  $log = Logger.new(logfilename)
  $log.level = Logger::DEBUG


  colors = Ncurses.COLORS
  back = :black
  lineback = :blue
  back = 234 if colors >= 256
  lineback = 236 if colors >= 256

  catch(:close) do
    @window = VER::Window.root_window
    @form = Form.new @window
    @form.bind_key(KEY_F1, 'help'){ display_app_help }

    header = app_header "0.0.8", :text_center => "Pad based tabular_widget", :text_right =>"" , :name => "header" , :color => :white, :bgcolor => lineback , :attr => :bold 



    _col = "#[fg=yellow]"
    $message = Variable.new
    $message.value = ""
    @status_line = status_line :row => Ncurses.LINES-1 #, :bgcolor => :red, :color => :yellow
    @status_line.command {
      "#[bg=236, fg=black]#{_col}F1#[/end] Help | #{_col}?#[/end] Keys | #{_col}M-c#[/end] Ask | #{_col}M-d#[/end] History | #{_col}M-m#[/end] Methods | %20s" % [$message.value]
    }

    h = FFI::NCurses.LINES-4
    w = FFI::NCurses.COLS
    r = 1
    #header = %w[ Status Widget Priority Description Stat Modified]
    #header = %w[ Pos Last Title Director Year Country Mins BW]
    file = "todocsv.csv"
    file = "movies1000.txt"
    lines = File.open(file,'r').readlines 
    arr = []
    lines.each { |l| arr << l.split("~") }
    lines = nil
    #lines.each { |l| arr << l.split("|") }

    tv = Lyra::TableWidget.new @form, :row => 1, :col => 0, :height => h, :width => w, :name => "tv", :suppress_borders => false do |b|

      #b.columns = header
      
      b.text arr

      b.model_row 1
      b.get_column(2).color = "red"
      b.column_width 0, 5
      b.column_width 1, 5
      b.column_width 4, 5
      #b.column_width 2, 5
      b.column_align 6, :right
      #b.column_width 2, b.calculate_column_width(2)
      b.column_width 2, 50
      b.column_width 3, 25
      b.column_width 5, 10
      #b.column_width 3, 55
      #b.column_hidden 1, true
    end
    mcr = Lyra::DefaultTableRenderer.new tv
    mcr.header_colors :yellow, :blue
    tv.renderer mcr
    mcr.column_model ( tv.column_model )
    tv.create_default_sorter

    # pressing ENTER on a method name will popup details for that method
    tv.bind(:PRESS) { |ev|
      if @current_index > 0
        w = ev.word_under_cursor.strip
        w = ev.text
      # the curpos does not correspond to the formatted display, this is just the array
      # without the width info XXX
        alert "#{ev.current_index}, #{ev.curpos}: #{w}"
      end
    }
    tv.bind_key(?e) { edit_row(tv) }
    tv.bind_key(?i) { insert_row(tv) }
    tv.bind_key(?D) { tv.delete_at tv.current_index }
    @form.bind_key(?\M-m, "Select methods") {
      tv = @form.by_name["tv"]; 
    }


    $message.value = "#{tv.current_index}: #{tv.lastrow}, #{tv.lastcol}"
    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    while((ch = @window.getchar()) != KEY_F10 )
      break if ch == ?q.ord || ch == ?\C-q.getbyte(0)
      @form.handle_key(ch)
      $message.value = "#{tv.current_index}: #{tv.lastrow}, #{tv.lastcol}"
      @window.wrefresh
    end
  end
rescue => ex
  textdialog ["Error in rib: #{ex} ", *ex.backtrace], :title => "Exception"
  $log.debug( ex) if ex
  $log.debug(ex.backtrace.join("\n")) if ex
ensure
  @window.destroy if !@window.nil?
  VER::stop_ncurses
  p ex if ex
  p(ex.backtrace.join("\n")) if ex
end
  # a test renderer to see how things go
