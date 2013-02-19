lyra
====

lightning-fast file navigator

Screenshot:
     http://oi47.tinypic.com/35bt7b9.jpg

##INSTALL##

*  Copy lyra.rb into PATH, e.g. $HOME/bin
*  alias as: 

    alias y=~/bin/lyra.rb
*  run as:  

    y

*  profit!

## Pre-requisites ##

This relies only on **ruby 1.9.3** (io/wait) so as to get a single key with timeout. The timeout is needed
  to get Alt keys, Function keys, page up/down, home, end, and arrow keys. Highline also allows getting
  of a single char, but not sure if it allows a timeout. Actually for this softwares minimal needs
  we can avoid those keys and focus only on control-keys, however, accidental pressing of arrow keys does result in various character keys getting read, so it can have undesirable effects since we execute commands mostly without ENTER being pressed.

Oh wait, I also use **zsh** for getting the files. Actually, i guess i could just use ruby for that, but we'll see -- zfm used zsh's capabilities a lot, if I don't then I'll skip zsh. For the moment, if you don't have zsh, just do `brew install zsh` or maybe replace the zsh call with `sh -c echo *`.

## Keys ##

*  ?  - help (will always display latest bindings)
*  M-n and M-p for paging
*  1-9a-zA-Z for selecting a file and opening it (or cd into it)
*  @  go into selection mode (toggle). selection keys will add to list of selected files (toggle actually)
*  !  go into command mode, upon selecting a file, will ask for command to run on file
*  /  will ask for regex pattern to filter file list
*  "," go to parent dir (mnemonic is "&lt;")
*  +   ask for path to goto (or open if file)
*  `   (backtick) menu for sorting, running ack/locate/find etc


Other navigation keys are being added for popping, changing dir etc. 

## Motivation ##

This is a tiny ruby port of the much larger zfm written in zsh. I only want to implement a minimal
set of zfm's functionality. I aim to keep this in one file so it can just be put into the path, and executed.

## Others ##

I don't see myself implementing the whole vim bindings here, since HINT mode is really faster for getting to a file in one stroke. Also, the whole arrow key movement thing in zfm is nice to look at but is a slow way of navigation. I might boldface selected files currently there's just an "x" mark on it.

Please try out zfm, it rocks (IMO).

lyra is named after a constellation, not Lyra Belacqua !
