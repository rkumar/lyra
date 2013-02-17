#!/usr/bin/env ruby
require 'readline'
require 'io/wait'
# -- requires 1.9.3 for io/wait
# -- cannot do with Highline since we need a timeout on wait, not sure if HL can do that
## Adapted from:
#http://stackoverflow.com/questions/174933/how-to-get-a-single-character-without-pressing-enter/8274275#8274275
# Need to take complex keys and matc against a hash.

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


def char_if_pressed
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

# if i put this inside the function, then I keep getting that 
# error message by zsh : unable to perform all requested operations
# However putting this globally means that newlines are not printed !
#system("stty raw -echo") # turn raw input on
#while true
  ##system("stty raw -echo 2>/dev/null") # turn raw input on
  #c = char_if_pressed
  ##system("stty -raw echo 2>/dev/null") # turn raw input on
  #puts "[#{c}]" if c
  #exit if c == 'q'
  ##sleep 1
  ##puts "tick"
#end
require 'highline/import'
#require 'highline/system_extensions' 
#def getch()
  #HighLine::SystemExtensions.raw_no_echo_mode; 
  #c = HighLine::SystemExtensions.get_character; 
  #HighLine::SystemExtensions.restore_mode;
  #c
#end

$IDX="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
$selected_files = Array.new
$selection_mode = false
$command_mode = false

def run()
  ctr=0
  $files = `zsh -c 'print -rl -- *(M)'`.split("\n")
  if $files.nil? || $files.empty?
    exit 0
  end
  fl=$files.size

  selectedix = nil
  patt=""
  sta=0
  while true
    i = 0
    if patt
      view = $files.grep(/#{patt}/)
    else 
      view = $files
    end
    fl=view.size
    sta = 0 if sta > fl || sta < 0
    vp = view[sta, 60]
    system("clear")
    buff = columnate vp, 25
    buff.each {|line| print line, "\n" }
    print
    #while i < 25 
      #ind=$IDX[i]
      #mark=""
      #mark="x" if selectedix == i
      #print "#{mark}#{ind}) #{view[ctr]} \n"
      #i += 1
      #ctr += 1
      #break if ctr >= fl
    #end
    print "#{$files.size}, #{view.size} sta=#{sta} (#{patt}): "
    ch = char_if_pressed
    puts
    break if ch == 'q' 
    # next line was catching M-p space etc 
    #if ( (ch >= 'a' && ch <= 'z') || ( ch >= "A" && ch <= "Z" ))
    if  ch =~ /^[1-9a-zA-Z]$/
      # this is insert mode, not hint mode
      #patt += ch
      # hint mode
      select_hint vp, ch
      ctr = 0
    elsif ch == "BACKSPACE"
      patt = patt[0..-2]
      ctr = 0
    elsif ch == "/"
      print "Enter pattern: "
      patt = gets
      patt.chomp!
      ctr = 0
    elsif ch == "SPACE"
      sta += 60
    elsif ch == "M-n"
      sta += 60
    elsif ch == "M-p"
      sta -= 60
    elsif ch == "@"
      $selection_mode = !$selection_mode
    elsif ch == "!"
      $command_mode = !$command_mode
    elsif ch == ","
      change_dir ".."
    else
      p ch
    end
  end
end
def columnate ary, sz
  buff=Array.new
  # ix refers to the index in the complete file list, wherease we only show 60 at a time
  ix=0
  wid=30
  while true
    ## ctr refers to the index in the column
    ctr=0
    while ctr < sz
      ind=$IDX[ix]
      mark="   "
      mark=" x " if $selected_files.index(ary[ix])

      s = "#{ind}#{mark}#{ary[ix].ljust(wid)}"
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
    if $selection_mode
      toggle_select f
    elsif $command_mode
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
  else
    system("$EDITOR #{f}")
  end
end
def run_command f
  print "Run a command on #{f}: "
  command = gets().chomp
  print "Second part of command: "
  command2 = gets().chomp
  puts "#{command} #{f} #{command2}"
  system "#{command} #{f} #{command2}"
end

def change_dir f
    Dir.chdir f
    $files = `zsh -c 'print -rl -- *(M)'`.split("\n")
end
run if __FILE__ == $PROGRAM_NAME
