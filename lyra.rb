#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: lyra.rb
#  Description: Fast file navigation, a tiny version of zfm
#       Author: rkumar http://github.com/rkumar/lyra/
#         Date: 2013-02-17 - 17:48
#      License: GPL
#  Last update: 2013-02-20 19:59
# ----------------------------------------------------------------------------- #
#  lyra.rb  Copyright (C) 2012-2013 rahul kumar
#require 'readline'
require 'io/wait'
# http://www.ruby-doc.org/stdlib-1.9.3/libdoc/shellwords/rdoc/Shellwords.html
require 'shellwords'
# -- requires 1.9.3 for io/wait
# -- cannot do with Highline since we need a timeout on wait, not sure if HL can do that

## INSTALLATION
# copy into PATH
# alias y=~/bin/lyra.rb
# y
VERSION="0.0.7-alpha"
O_CONFIG=true

$bindings = {}
$bindings = {
  "`"   => "main_menu",
  "="   => "toggle_menu",
  "!"   => "command_mode",
  "@"   => "selection_mode_toggle",
  "M-a" => "select_all",
  "M-A" => "unselect_all",
  ","   => "goto_parent_dir",
  "+"   => "goto_dir",
  "."   => "pop_dir",
  "'"   => "goto_bookmark",
  "/"   => "enter_regex",
  "M-p"   => "prev_page",
  "M-n"   => "next_page",
  "SPACE"   => "next_page",
  "M-f"   => "select_visited_files",
  "M-d"   => "select_used_dirs",
  "M-b"   => "select_bookmarks",
  "M-m"   => "create_bookmark",
  "M-M"   => "show_marks",
  "C-c"   => "refresh",
  "ESCAPE"   => "refresh",

  "?"   => "print_help",
  "F1"   => "print_help"

}

## clean this up a bit, copied from shell program and macro'd 
$kh=Hash.new
$kh["OP"]="F1"
$kh["[A"]="UP"
$kh["[5~"]="PGUP"
$kh['']="ESCAPE"
KEY_PGDN="[6~"
KEY_PGUP="[5~"
## I needed to replace the O with a [ for this to work
#  in Vim Home comes as ^[OH whereas on the command line it is correct as ^[[H
KEY_HOME='[H'
KEY_END="[F"
KEY_F1="OP"
KEY_UP="[A"
KEY_DOWN="[B"

$kh[KEY_PGDN]="PgDn"
$kh[KEY_PGUP]="PgUp"
$kh[KEY_HOME]="Home"
$kh[KEY_END]="End"
$kh[KEY_F1]="F1"
$kh[KEY_UP]="UP"
$kh[KEY_DOWN]="DOWN"
KEY_LEFT='[D' 
KEY_RIGHT='[C' 
$kh["OQ"]="F2"
$kh["OR"]="F3"
$kh["OS"]="F4"
$kh[KEY_LEFT] = "LEFT"
$kh[KEY_RIGHT]= "RIGHT"
KEY_F5='[15~'
KEY_F6='[17~'
KEY_F7='[18~'
KEY_F8='[19~'
KEY_F9='[20~'
KEY_F10='[21~'
$kh[KEY_F5]="F5"
$kh[KEY_F6]="F6"
$kh[KEY_F7]="F7"
$kh[KEY_F8]="F8"
$kh[KEY_F9]="F9"
$kh[KEY_F10]="F10"

## get a character from user and return as a string
# Adapted from:
#http://stackoverflow.com/questions/174933/how-to-get-a-single-character-without-pressing-enter/8274275#8274275
# Need to take complex keys and matc against a hash.
def get_char
  begin
    system("stty raw -echo 2>/dev/null") # turn raw input on
    c = nil
    #if $stdin.ready?
      c = $stdin.getc
      cn=c.ord
      return "BACKSPACE" if cn == 127
      return "C-SPACE" if cn == 0
      return "SPACE" if cn == 32
      if cn >= 0 && cn < 27
        x= cn + 96
        return "C-#{x.chr}"
      end
      if c == ''
        buff=c.chr
        while true
          k = nil
          if $stdin.ready?
            k = $stdin.getc
            #puts "got #{k}"
            buff += k.chr
          else
            x=$kh[buff]
            return x if x
            #puts "returning with  #{buff}"
            if buff.size == 2
              ## possibly a meta/alt char
              k = buff[-1]
              return "M-#{k.chr}"
            end
            return buff
          end
        end
      end
    #end
    return c.chr if c
  ensure
    #system "stty -raw echo" # turn raw input off
    system("stty -raw echo 2>/dev/null") # turn raw input on
  end
end

#require 'highline/import'

$IDX="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
$pagesize = 60
$selected_files = Array.new
$bookmarks = {}
#$selection_mode = false
#$command_mode = false
$mode = nil
LINES=%x(tput lines).to_i
COLS=%x(tput cols).to_i
ROWS = LINES - 4
CLEAR      = "\e[0m"
BOLD       = "\e[1m"
BOLD_OFF       = "\e[22m"
RED        = "\e[31m"
GREEN      = "\e[32m"
YELLOW     = "\e[33m"
BLUE       = "\e[34m"
REVERSE    = "\e[7m"
$patt=nil
$ignorecase = true

$visited_files = []
## dir stack for popping
$visited_dirs = []
## dirs where some work has been done, for saving and restoring
$used_dirs = []

#$help = "#{BOLD}1-9a-zA-Z#{BOLD_OFF} Select #{BOLD}/#{BOLD_OFF} Grep #{BOLD}'#{BOLD_OFF} First char  #{BOLD}M-n/p#{BOLD_OFF} Paging  #{BOLD}!#{BOLD_OFF} Command Mode  #{BOLD}@#{BOLD_OFF} Selection Mode  #{BOLD}q#{BOLD_OFF} Quit"

$help = "#{BOLD}?#{BOLD_OFF} Help  #{BOLD}!#{BOLD_OFF} Command Mode  #{BOLD}=#{BOLD_OFF} Toggle Menu #{BOLD}@#{BOLD_OFF} Selection Mode  #{BOLD}q#{BOLD_OFF} Quit "

def run()
  ctr=0
  config_read
  $files = `zsh -c 'print -rl -- *(#{$hidden}M)'`.split("\n")
  fl=$files.size

  selectedix = nil
  $patt=""
  $sta=0
  while true
    i = 0
    if $patt
      if $ignorecase
        $view = $files.grep(/#{$patt}/i)
      else
        $view = $files.grep(/#{$patt}/)
      end
    else 
      $view = $files
    end
    fl=$view.size
    $sta = 0 if $sta >= fl || $sta < 0
    vp = $view[$sta, $pagesize]
    fin = $sta + vp.size
    $title ||= Dir.pwd
    system("clear")
    # title
    print "#{GREEN}#{$help}  #{BLUE}lyra #{VERSION}#{CLEAR}\n"
    print "#{BOLD}#{$title}  #{$sta + 1} to #{fin} of #{fl}#{CLEAR}\n"
    $title = nil
    buff = columnate vp, ROWS
    # needed the next line to see how much extra we were going in padding
    #buff.each {|line| print "#{REVERSE}#{line}#{CLEAR}\n" }
    buff.each {|line| print line, "\n"  }
    print
    # prompt
    #print "#{$files.size}, #{view.size} sta=#{sta} (#{patt}): "
    _mm = ""
    _mm = "[#{$mode}] " if $mode
    print "\r#{_mm}#{$patt} >"
    ch = get_char
    #puts
    break if ch == 'q' 
    if  ch =~ /^[1-9a-zA-Z]$/
      # this is insert mode, not hint mode
      #patt += ch
      # hint mode
      select_hint vp, ch
      ctr = 0
    elsif ch == "BACKSPACE"
      $patt = $patt[0..-2]
      ctr = 0
    else
      binding = $bindings[ch]
      send(binding) if binding
      #p ch
    end
  end
  puts "bye"
  config_write
end

## code related to long listing of files
GIGA_SIZE = 1073741824.0
MEGA_SIZE = 1048576.0
KILO_SIZE = 1024.0

# Return the file size with a readable style.
def readable_file_size(size, precision)
  case
    #when size == 1 : "1 B"
  when size < KILO_SIZE then "%d B" % size
  when size < MEGA_SIZE then "%.#{precision}f K" % (size / KILO_SIZE)
  when size < GIGA_SIZE then "%.#{precision}f M" % (size / MEGA_SIZE)
  else "%.#{precision}f G" % (size / GIGA_SIZE)
  end
end
def date_format t
  t.strftime "%Y/%m/%d"
end
## 
#
# print in columns
# ary - array of data
# sz  - lines in one column
#
def columnate ary, sz
  buff=Array.new
  return buff if ary.nil? || ary.size == 0
  
  # determine width based on number of files to show
  # if less than sz then 1 col and full width
  #
  wid = 30
  ars = ary.size
  ars = [$pagesize, ary.size].min
  d = 4
  if ars <= sz
    wid = COLS - d
  elsif ars < sz * 2
    wid = COLS/2 - d
  elsif ars < sz * 3
    wid = COLS/3 - d
  end

  # ix refers to the index in the complete file list, wherease we only show 60 at a time
  ix=0
  while true
    ## ctr refers to the index in the column
    ctr=0
    while ctr < sz
      ind=$IDX[ix]
      mark="   "
      mark=" x " if $selected_files.index(ary[ix])

      f = ary[ix]
      if $long_listing
        stat = File.stat(f)
        #"%-*s\t%10s\t%s" % [max_len,f,  readable_file_size(stat.size,1), date_format(stat.mtime)]
        f = "%10s  %s  %s" % [readable_file_size(stat.size,1), date_format(stat.mtime), f]
      end
      if f.size > wid
        f = f[0, wid-2]+"$ "
      else
        f = f.ljust(wid)
      end

      #s = "#{ind}#{mark}#{ary[ix].ljust(wid)}"
      s = "#{ind}#{mark}#{f}"
  
      if buff[ctr]
        buff[ctr] += s
      else
        buff[ctr] = s
      end

      ctr+=1
      ix+=1
      break if ix >= ary.size
    end
    break if ix >= ary.size
  end
  return buff
end
def select_hint view, ch
  ix = $IDX.index(ch)
  if ix
    f = view[ix]
    if $mode == 'SEL'
      toggle_select f
    elsif $mode == 'COM'
      run_command f
    else
      open_file f
    end
    #selectedix=ix
  end
end
def toggle_select f
  if $selected_files.index f
    $selected_files.delete f
  else
    $selected_files.push f
  end
end
def open_file f
  if File.directory? f
    change_dir f
  elsif File.readable? f
    system("$EDITOR #{Shellwords.escape(f)}")
    f = Dir.pwd + "/" + f if f[0] != '/'
    $visited_files.insert(0, f)
    push_used_dirs Dir.pwd
  else
    perror "open_file: #{f} not found"
      # could check home dir or CDPATH env variable DO
  end
end
def run_command f
  files=nil
  case f
  when Array
    # escape the contents and create a string
    files = Shellwords.join(f)
  when String
    files = Shellwords.escape(f)
  end
  print "Run a command on #{files}: "
  command = gets().chomp
  print "Second part of command: "
  command2 = gets().chomp
  puts "#{command} #{files} #{command2}"
  system "#{command} #{files} #{command2}"
  puts "Press a key ..."
  push_used_dirs Dir.pwd
  get_char
end

def change_dir f
  $visited_dirs.insert(0, Dir.pwd)
  f = File.expand_path(f)
  Dir.chdir f
  #$files = `zsh -c 'print -rl -- *(M)'`.split("\n")
  $files = `zsh -c 'print -rl -- *(#{$hidden}M)'`.split("\n")
  $patt=nil
end
def refresh
    #$files = `zsh -c 'print -rl -- *(M)'`.split("\n")
    $files = `zsh -c 'print -rl -- *(#{$hidden}M)'`.split("\n")
    $patt=nil
end
def unselect_all
  $selected_files = []
end
def select_all
  $selected_files = $view.dup
end
def goto_dir
  print "Enter path: "
  path = gets.chomp
  open_file File.expand_path(path)
end
def selection_mode_toggle
      if $mode == 'SEL'
        # we seem to be coming out of select mode with some files
        if $selected_files.size > 0
          run_command $selected_files
        end
        $mode = nil
      else
        #$selection_mode = !$selection_mode
        $mode = 'SEL'
      end
end
## toggle command mode
def command_mode
  if $mode == 'COM'
    $mode = nil
    return
  end
  $mode = 'COM'
end
def goto_parent_dir
  change_dir ".."
end
def goto_entry_starting_with fc=nil
  unless fc
    print "Entries starting with: "
    fc = get_char
  end
  return if fc.size != 1
  $patt = "^#{fc}"
  ctr = 0
end
def goto_bookmark ch=nil
  unless ch
    print "Enter bookmark char: "
    ch = get_char
  end
  if ch =~ /^[A-Z]$/
    d = $bookmarks[ch]
    if d
      change_dir d
    else
      perror "#{ch} not a bookmark"
    end
  else
    goto_entry_starting_with ch
  end
end

def enter_regex
  print "Enter pattern: "
  $patt = gets
  $patt.chomp!
  ctr = 0
end
def next_page
  $sta += $pagesize
end
def prev_page
  $sta -= $pagesize
end
def print_help
  system("clear")
  puts "HELP"
  puts
  puts "To open a file or dir press 1-9 a-z A-Z "
  puts "Command Mode: Will prompt for a command to run on a file, after selecting using hotkey"
  puts "Selection Mode: Each selection adds to selection list (toggles)"
  puts "                Upon exiting mode, user is prompted for a command to run on selected files"
  puts
  $bindings.each_pair { |k, v| puts "#{k.ljust(7)}  =>  #{v}" }
  get_char

end
def show_marks
  puts
  puts "Bookmarks: "
  $bookmarks.each_pair { |k, v| puts "#{k.ljust(7)}  =>  #{v}" }
  puts
  print "Enter bookmark to goto: "
  ch = get_char
  goto_bookmark(ch) if ch =~ /^[A-Z]$/
end
def main_menu
  h = { "s" => "sort_menu", "f" => "filter_menu", "c" => "command_menu" , "x" => "extras"}
  menu "Main Menu", h
end
def toggle_menu
  h = { "h" => "toggle_hidden", "c" => "toggle_case", "l" => "toggle_long_list" , "1" => "toggle_columns"}
  menu "Toggle Menu", h
end
def menu title, h
  return unless h

  pbold "#{title}"
  h.each_pair { |k, v| puts "#{k}: #{v}" }
  ch = get_char
  binding = h[ch]
  if binding
    if respond_to?(binding, true)
      send(binding)
    end
  end
  return ch, binding
end
def toggle_menu
  h = { "h" => "toggle_hidden", "c" => "toggle_case", "l" => "toggle_long_list" , "1" => "toggle_columns"}
  ch, menu_text = menu "Toggle Menu", h
  case menu_text
  when "toggle_hidden"
    $hidden = $hidden ? nil : "D"
    refresh
  when "toggle_case"
    #$ignorecase = $ignorecase ? "" : "i"
    $ignorecase = !$ignorecase
    refresh
  when "toggle_columns"
    $pagesize = $pagesize==60 ? ROWS : 60
  when "toggle_long_list"
    $long_listing = !$long_listing
    $pagesize = ROWS
    refresh
  end
end

def sort_menu
  lo = nil
  h = { "n" => "newest", "o" => "oldest", 
    "l" => "largest", "s" => "smallest" , "m" => "name" , "r" => "rname", "d" => "dirs", "c" => "clear" }
  ch, menu_text = menu "Sort Menu", h
  case menu_text
  when "newest"
    lo="om"
  when "oldest"
    lo="Om"
  when "largest"
    lo="OL"
  when "smallest"
    lo="oL"
  when "name"
    lo="on"
  when "rname"
    lo="On"
  when "dirs"
    lo="/"
  when "clear"
    lo=""
  end
  ## This needs to persist and be a part of all listings, put in change_dir.
  $files = `zsh -c 'print -rl -- *(#{lo}#{$hidden}M)'`.split("\n") if lo
  #$files =$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
end

def command_menu
  ## 
  #  since these involve full paths, we need more space, like only one column
  #
  ## in these cases, getting back to the earlier dir, back to earlier listing
  # since we've basically overlaid the old listing
  #
  # should be able to sort THIS listing and not rerun command. But for that I'd need to use
  # xargs ls -t etc rather than the zsh sort order. But we can run a filter using |.
  #
  h = { "a" => "ack", "f" => "ffind", "l" => "locate", "t" => "today" }
  ch, menu_text = menu "Command Menu", h
  case menu_text
  when "ack"
    print "Enter a pattern to search: "
    pattern = gets.chomp
    $files = `ack -l #{pattern}`.split("\n")
  when "ffind"
    print "Enter a pattern to find: "
    pattern = gets.chomp
    $files = `find . -name #{pattern}`.split("\n")
  when "locate"
    print "Enter a pattern to locate: "
    pattern = gets.chomp
    $files = `locate #{pattern}`.split("\n")
  when "today"
    $files = `zsh -c 'print -rl -- *(#{$hidden}Mm0)'`.split("\n")
  end
end
def extras
  h = { "1" => "one_column", "2" => "multi_column", "r" => "config_read" , "w" => "config_write"}
  ch, menu_text = menu "Extras Menu", h
  case menu_text
  when "one_column"
    $pagesize = ROWS
  when "multi_column"
    $pagesize = 60

  end
end
def select_used_dirs
  $title = "Used Directories"
  $files = $used_dirs.uniq
end
def select_visited_files
  # not yet a unique list, needs to be unique and have latest pushed to top
  $title = "Visited Files"
  $files = $visited_files.uniq
end
def select_bookmarks
  $title = "Bookmarks"
  $files = $bookmarks.values
end

## part copied and changed from change_dir since we don't dir going back on top
#  or we'll be stuck in a cycle
def pop_dir
  # the first time we pop, we need to put the current on stack
  if !$visited_dirs.index(Dir.pwd)
    $visited_dirs.push Dir.pwd
  end
  ## XXX make sure thre is something to pop
  d = $visited_dirs.delete_at 0
  ## XXX make sure the dir exists, cuold have been deleted. can be an error or crash otherwise
  $visited_dirs.push d
  Dir.chdir d
  $files = `zsh -c 'print -rl -- *(#{$hidden}M)'`.split("\n")
  $patt=nil
end
def config_read
  f =  File.expand_path("~/.zfminfo")
  if File.readable? f
    load f
    # maybe we should check for these existing else crash will happen.
    $used_dirs.push(*(DIRS.split ":"))
    $visited_files.push(*(FILES.split ":"))
    #$bookmarks.push(*bookmarks) if bookmarks
    chars = ('A'..'Z')
    chars.each do |ch|
      if Kernel.const_defined? "BM_#{ch}"
        $bookmarks[ch] = Kernel.const_get "BM_#{ch}"
      end
    end
  end
end

def config_write
  # Putting it in a format that zfm can also read and write
  f1 =  File.expand_path("~/.zfminfo")
  d = $used_dirs.join ":"
  f = $visited_files.join ":"
  File.open(f1, 'w+') do |f2|  
    # use "\n" for two lines of text  
    f2.puts "DIRS=\"#{d}\""
    f2.puts "FILES=\"#{f}\""
    $bookmarks.each_pair { |k, val| 
      f2.puts "BM_#{k}=\"#{val}\""
      #f2.puts "BOOKMARKS[\"#{k}\"]=\"#{val}\""
    }
  end
end
def create_bookmark
  print "Enter (upper case) char for bookmark: "
  ch = get_char
  if ch =~ /^[A-Z]$/
    $bookmarks[ch] = Dir.pwd
  else
    print "Bookmark must be upper-case character"
    get_char
  end
end

def push_used_dirs d=Dir.pwd
  $used_dirs.index(d) || $used_dirs.push(d)
end
def pbold text
  puts "#{BOLD}#{text}#{BOLD_OFF}"
end
def perror text
  puts "#{RED}#{text}#{CLEAR}"
  get_char
end

run if __FILE__ == $PROGRAM_NAME
