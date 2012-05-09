Quicksilver
-----------

Quicksilver is a VIM plugin whose purpose is to quicken the process of
opening files from inside VIM.

Preview
-------

[Video](http://www.youtube.com/watch?v=RDsey4YqpHs)

![Screenshot](http://farm4.static.flickr.com/3383/5804126014_072806d823_z.jpg)

Installation
------------

Use [pathogen][1] and clone this repo into your ~/.vim/bundle directory.

Mappings
--------

By default, `<leader>q` will activate the Quicksilver buffer and switch to
insert mode. Typing any key will update the list of suggestions and pressing
`CR` will open the first item in the suggestion list. Use `C-c` to quickly
close the buffer.

You can change the `<leader>q` mapping with the following in your `vimrc`.

    nmap <leader>r <Plug>ActivateQS

To map it to `<leader>r`

You may cycle through the suggestion list using `Tab` and `S-Tab`. `CR` will
open the current suggestion (that's the first item in the list of matches).

If there is only one item in the suggestion list, pressing `Tab` will open
that item.

Pressing `CR` when there is no pattern will go up a directory.

`C-w` clears the entire pattern. If there is no pattern, it will go up a
directory.

`C-t` toggles whether or not to ignore filename character case. Case is
ignored by default.

If a file with the given pattern does not exist then a new file will be
opened for editing with the given pattern as its filename. If a pattern
ends in `/`, quicksilver will create a new folder, change its CWD to
that folder and remain in insert mode expecting a file name.

Matching
--------

`C-f` turns on `fuzzy matching`. Fuzzy matching will match any filename
that contains every character in the pattern in order. For example, the
pattern `rdm` will match `README` but not `REMADE`.

`C-n` turns on `normal matching`. Normal matching will match any
filename that contains the exact pattern within it. For example, the
pattern `foo` will match `foo` and `foob` but not `ofo` or `oof`.

If you prefer fuzzy matching and would like Quicksilver to default to using it
instead of normal matching then you can add `let g:QSMatchFn = "fuzzy"`
to your `.vimrc`.

Patterns that start or end in a wildcard (`*`) are treated as glob
patterns. For example, the pattern `*.md` will open all the files that
have the extension `.md` in the CWD.

Other
-----

It is possible to ignore certain items by setting a global variable
`g:QSIgnored` that contains one or more regular expressions separated by a
semicolon. For example, to ignore files with the .pyc extension and files with
the .swp extension, one could add the following line to their .vimrc file:
    
    let g:QSIgnored = "\\.pyc$;\\.swp$"

This feature was inspired by [ombarg][2]'s fork.

Windows-specific
----------------

On Windows it is possible to switch partitions by using the `QSChangeDrive`
command. Simply execute it (`:QSChangeDrive<CR>`) and you will be asked for a
drive to change to.

Requirements
------------

* VIM 7.0+ compiled with +python
* Python 2.6+

[1]: http://github.com/tpope/vim-pathogen
[2]: https://github.com/obmarg
