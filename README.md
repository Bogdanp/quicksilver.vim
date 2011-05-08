Quicksilver
===========

Quicksilver is a VIM plugin whose puprose is to expediate the process of
opening files from inside VIM.

# Preview

[Video](http://www.youtube.com/watch?v=Jq3tQL_r9BY).

![Screenshot](http://farm4.static.flickr.com/3497/5699173083_56198782fe_z.jpg)

# Installation

Use [pathogen][1] and clone this repo into your ~/.vim/bundle directory.

# Usage

By default, `\q` will activate the Quicksilver buffer and switch to
insert mode. Typing any key will update the list of suggestions and
pressing `CR` will open the first item in the suggestion list. Use `^c`
to quickly close the buffer.

Pressing `Tab` or `CR` when there's no pattern will go up a directory.

`C-w` clears the entire pattern. If there is no pattern, it will go up a
directory.

If a file with the given pattern does not exist then it will be created
and opened for editing, patterns ending in `/` create new folders
instead.

# Requirements

* VIM 7.0+ compiled with +python
* Python 2.6+

[1]: http://github.com/tpope/vim-pathogen
