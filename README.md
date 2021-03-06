lyra
====

Pad versions of various rbcurse multiline widgets such as table (tabular-widget) and later
tree etc.

All widgets are to extend textpad or in worst cases contain a textpad. Extending textpad is the easier way
with least code.

All widgets must maintain functionality and API of their earlier counterparts which I admit are quite screwed
due to the attr-accessor mess.

------

Ignore following. The executable lyra was continued as cetus gem.

lightning-fast file navigator

Screenshot:
     http://oi47.tinypic.com/35bt7b9.jpg

##INSTALL##

*  Copy lyra.rb into PATH, e.g. $HOME/bin
*  alias as: 

    alias y=~/bin/lyra.rb
*  run as:  

    y

* lyra has not been pushed as a gem. you can install locally with:
  
   gem build lyra.gemspec
   gem install --local lyra

You may need this to run some examples in the examples dir.

*  profit!

## Pre-requisites ##

This relies only on **ruby 1.9.3** (io/wait) so as to get a single key with timeout. The timeout is needed
  to get Alt keys, Function keys, page up/down, home, end, and arrow keys. Highline also allows getting
  of a single char, but not sure if it allows a timeout. Actually for this softwares minimal needs
  we can avoid those keys and focus only on control-keys, however, accidental pressing of arrow keys does result in various character keys getting read, so it can have undesirable effects since we execute commands mostly without ENTER being pressed.

Oh wait, I also use **zsh** for getting the files. Actually, i guess i could just use ruby for that, but we'll see -- zfm used zsh's capabilities a lot, if I don't then I'll skip zsh. For the moment, if you don't have zsh, just do `brew install zsh` or maybe replace the zsh call with `sh -c echo *`.

## Keys ##

*  ?  - help (will always display latest bindings)
*  M-n and M-p for paging (also SPACE)
*  1-9a-zA-Z for selecting a file and opening it (or cd into dir)
*  @  go into selection mode (toggle). selection keys will add to list of selected files (toggle actually)
*  !  go into command mode, upon selecting a file, will ask for command to run on file/dir
*  /  will ask for regex pattern to filter file list
*  "," (comma) go to parent dir (mnemonic is "&lt;")
*  .   (dot) pop directories (go back)
*  +   ask for path to goto (or open if file)
*  `   (backtick) menu for sorting, running ack/locate/find etc
*  M-d  - visited directories (where a file has been opened or command run)
*  M-f  - visited files
*  M-m  - Create a bookmark for current directory
*  '   (single quote) go to bookmark
*  M-M  - Show marks
*  Q to quit

Other navigation keys are being added for popping, changing dir etc. Check "?" for latest bindings.

## Motivation ##

This is a tiny ruby port of the much larger zfm written in zsh. I only want to implement a minimal
set of zfm's functionality. I aim to keep this in one file so it can just be put into the path, and executed.

## Others ##

I don't see myself implementing the whole vim bindings here, since HINT mode is really faster for getting to a file in one stroke. Also, the whole arrow key movement thing in zfm is nice to look at but is a slow way of navigation. I might boldface selected files currently there's just an "x" mark on it.

## Files ##

Currently no config file, but bookmarks and visited files and dirs are saved in $HOME/.lyrainfo upon quitting.

Please try out zfm, it rocks (IMO). Find it on github (https://github.com/rkumar/zfm)

lyra is named after a constellation, not Lyra Belacqua !

NOTE: I am continuing development on cetus http://github.com/rkumar/cetus -- I employ a different indexing strategy and I've then developed much further than that. Check out cetus, please.
