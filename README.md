Quicksilver
===========

Quicksilver is a VIM plugin whose puprose is to expediate the opening of
files from inside VIM.

# Preview

![Screenshot](http://farm4.static.flickr.com/3497/5699173083_56198782fe_z.jpg)

# Installation

Use [pathogen][1] and clone this repo into your ~/.vim/bundle directory.

# Usage

By default, `\q` will activate the Quicksilver buffer and switch to
insert mode. Typing any key will update the list of suggestions and
pressing `CR` will open the first item in the suggestion list. Use `^c`
to quickly close the buffer.

# Requirements

* VIM 7.0+ compiled with +python
* Python 2.6+

[1]: http://github.com/tpope/vim-pathogen
