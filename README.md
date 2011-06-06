Quicksilver
===========

Quicksilver is a VIM plugin whose puprose is to quicken the process of
opening files from inside VIM.

# Preview

[Video](http://www.youtube.com/watch?v=RDsey4YqpHs)

![Screenshot](http://farm4.static.flickr.com/3383/5804126014_072806d823_z.jpg)

# Installation

Use [pathogen][1] and clone this repo into your ~/.vim/bundle directory.

# Usage

By default, `\q` will activate the Quicksilver buffer and switch to
insert mode. Typing any key will update the list of suggestions and
pressing `CR` will open the first item in the suggestion list. Use `C-c`
to quickly close the buffer.

Pressing `Tab` or `CR` when there's no pattern will go up a directory.

`C-w` clears the entire pattern. If there is no pattern, it will go up a
directory.

`C-t` toggles between if pattern and filename case should be ignored or
not.

`C-f` turns on `fuzzy matching`. Fuzzy matching will match any filename
that contains every character in the given pattern, no matter the order
of the characters. For example: the pattern `foo` will match `foo`, as
well as `oof`, `ofo`, `foob`, etc.

`C-n` turns on `normal matching`. Normal matching will match any
filename that contains the exact phrase within it. For example: the
pattern `foo` will match `foo` and `foob` but not `ofo` or `oof`.

If you prefer normal matching and would like Quicksilver to default
to it instead of fuzzy matching then you can add `let g:QSMatchFn =
'normal'` to your `.vimrc`.

If a file with the given pattern does not exist then it will be opened
for editing. If a pattern ends in `/`, quicksilver will create a
new folder, change its CWD to that folder and remain in insert mode
expecting a file name.

Patterns that start or end in a wildcard (`*`) are treated as glob
patterns. For example, the pattern `*.md` will open all the files that
have the extension `.md` in the CWD.

# Requirements

* VIM 7.0+ compiled with +python
* Python 2.6+

[1]: http://github.com/tpope/vim-pathogen
