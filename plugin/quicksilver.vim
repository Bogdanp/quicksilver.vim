" =======================================================================
" File:        quicksilver.vim
" Version:     0.0.1
" Description: VIM plugin that provides a fast way to open files.
" Maintainer:  Bogdan Popa <popa.bogdanp@gmail.com>
" License:     Copyright (C) 2011 Bogdan Popa
"
"              Permission is hereby granted, free of charge, to any
"              person obtaining a copy of this software and associated
"              documentation files (the "Software"), to deal in
"              the Software without restriction, including without
"              limitation the rights to use, copy, modify, merge,
"              publish, distribute, sublicense, and/or sell copies
"              of the Software, and to permit persons to whom the
"              Software is furnished to do so, subject to the following
"              conditions:
"
"              The above copyright notice and this permission notice
"              shall be included in all copies or substantial portions
"              of the Software.
"
"              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
"              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
"              TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
"              PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
"              THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
"              DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
"              CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
"              CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
"              IN THE SOFTWARE.
" ======================================================================

"{{{ Initial checks
if exists("g:loaded_quicksilver") || !has("python") || &cp
    finish
endif
let g:loaded_quicksilver = 1
"}}}
"{{{ Python code
python <<EOF
import os
import vim

class Quicksilver(object):
    def __init__(self):
        self.cwd = '{}/'.format(os.getcwd())

    def _cmp_files(self, x, y):
        "Files not starting with '.' come first."
        if x[0] == '.' and y[0] != '.':
            return 1
        if x[0] != '.' and y[0] == '.':
            return -1
        else:
            return cmp(x, y)

    def get_files(self):
        for f in os.listdir(self.cwd):
            path = os.path.join(self.cwd, f)
            yield '{}/'.format(f) if os.path.isdir(path) else f

    def match_files(self):
        files = [f for f in self.get_files() if self.pattern in f] 
        files.sort(cmp=self._cmp_files)
        if not self.pattern:
            files.insert(0, '../')
        return files

    def backspace(self):
        self.pattern = self.pattern[:-1]
        self.update('')

    def clear(self):
        self.pattern = ''
        self.update('')

    def close_buffer(self):
        vim.command('{} wincmd w'.format(
            vim.eval('bufwinnr("__Quicksilver__")')
        ))
        vim.command('bd!')

    def up_dir(self, path):
        return '/'.join(path.split('/')[:-3]) + '/'

    def open_file(self):
        try:
            path = os.path.join(self.cwd, self.match_files()[0])
            if self.match_files()[0] == '../':
                path = self.up_dir(path)
        except IndexError:
            self.close_buffer()
            return
        if os.path.isdir(path):
            self.cwd = path
            self.clear()
            vim.command('normal 0f ')
            return
        self.close_buffer()
        vim.command('edit {}'.format(path))

    def update(self, c):
        self.pattern += c
        vim.command('normal ggdG')
        vim.current.line = '{}{} {}'.format(
            self.cwd, self.pattern, self.match_files()
        )

quicksilver = Quicksilver()
EOF
"}}}
"{{{ Public interface
function! s:MapKeys() "{{{
    map  <silent><buffer><C-c> :python quicksilver.close_buffer()<CR>
    imap <silent><buffer><C-c> :python quicksilver.close_buffer()<CR>
    map  <silent><buffer><CR> :python quicksilver.open_file()<CR>0f i
    imap <silent><buffer><CR> :python quicksilver.open_file()<CR>0f i
    imap <silent><buffer><BS> :python quicksilver.backspace()<CR>0f i
    imap <silent><buffer>. :python quicksilver.update('.')<CR>0f i
    imap <silent><buffer>- :python quicksilver.update('-')<CR>0f i
    imap <silent><buffer>_ :python quicksilver.update('_')<CR>0f i
    imap <silent><buffer>+ :python quicksilver.update('+')<CR>0f i
    imap <silent><buffer>/ :python quicksilver.update('/')<CR>0f i
    imap <silent><buffer>\ :python quicksilver.update('\')<CR>0f i
    imap <silent><buffer>0 :python quicksilver.update('0')<CR>0f i
    imap <silent><buffer>1 :python quicksilver.update('1')<CR>0f i
    imap <silent><buffer>2 :python quicksilver.update('2')<CR>0f i
    imap <silent><buffer>3 :python quicksilver.update('3')<CR>0f i
    imap <silent><buffer>4 :python quicksilver.update('4')<CR>0f i
    imap <silent><buffer>5 :python quicksilver.update('5')<CR>0f i
    imap <silent><buffer>6 :python quicksilver.update('6')<CR>0f i
    imap <silent><buffer>7 :python quicksilver.update('7')<CR>0f i
    imap <silent><buffer>8 :python quicksilver.update('8')<CR>0f i
    imap <silent><buffer>9 :python quicksilver.update('9')<CR>0f i
    imap <silent><buffer>a :python quicksilver.update('a')<CR>0f i
    imap <silent><buffer>b :python quicksilver.update('b')<CR>0f i
    imap <silent><buffer>c :python quicksilver.update('c')<CR>0f i
    imap <silent><buffer>d :python quicksilver.update('d')<CR>0f i
    imap <silent><buffer>e :python quicksilver.update('e')<CR>0f i
    imap <silent><buffer>f :python quicksilver.update('f')<CR>0f i
    imap <silent><buffer>g :python quicksilver.update('g')<CR>0f i
    imap <silent><buffer>h :python quicksilver.update('h')<CR>0f i
    imap <silent><buffer>i :python quicksilver.update('i')<CR>0f i
    imap <silent><buffer>j :python quicksilver.update('j')<CR>0f i
    imap <silent><buffer>k :python quicksilver.update('k')<CR>0f i
    imap <silent><buffer>l :python quicksilver.update('l')<CR>0f i
    imap <silent><buffer>m :python quicksilver.update('m')<CR>0f i
    imap <silent><buffer>n :python quicksilver.update('n')<CR>0f i
    imap <silent><buffer>o :python quicksilver.update('o')<CR>0f i
    imap <silent><buffer>p :python quicksilver.update('p')<CR>0f i
    imap <silent><buffer>q :python quicksilver.update('q')<CR>0f i
    imap <silent><buffer>r :python quicksilver.update('r')<CR>0f i
    imap <silent><buffer>s :python quicksilver.update('s')<CR>0f i
    imap <silent><buffer>t :python quicksilver.update('t')<CR>0f i
    imap <silent><buffer>u :python quicksilver.update('u')<CR>0f i
    imap <silent><buffer>v :python quicksilver.update('v')<CR>0f i
    imap <silent><buffer>w :python quicksilver.update('w')<CR>0f i
    imap <silent><buffer>x :python quicksilver.update('x')<CR>0f i
    imap <silent><buffer>y :python quicksilver.update('y')<CR>0f i
    imap <silent><buffer>z :python quicksilver.update('z')<CR>0f i
    imap <silent><buffer>A :python quicksilver.update('A')<CR>0f i
    imap <silent><buffer>B :python quicksilver.update('B')<CR>0f i
    imap <silent><buffer>C :python quicksilver.update('C')<CR>0f i
    imap <silent><buffer>D :python quicksilver.update('D')<CR>0f i
    imap <silent><buffer>E :python quicksilver.update('E')<CR>0f i
    imap <silent><buffer>F :python quicksilver.update('F')<CR>0f i
    imap <silent><buffer>G :python quicksilver.update('G')<CR>0f i
    imap <silent><buffer>H :python quicksilver.update('H')<CR>0f i
    imap <silent><buffer>I :python quicksilver.update('I')<CR>0f i
    imap <silent><buffer>J :python quicksilver.update('J')<CR>0f i
    imap <silent><buffer>K :python quicksilver.update('K')<CR>0f i
    imap <silent><buffer>L :python quicksilver.update('L')<CR>0f i
    imap <silent><buffer>M :python quicksilver.update('M')<CR>0f i
    imap <silent><buffer>N :python quicksilver.update('N')<CR>0f i
    imap <silent><buffer>O :python quicksilver.update('O')<CR>0f i
    imap <silent><buffer>P :python quicksilver.update('P')<CR>0f i
    imap <silent><buffer>Q :python quicksilver.update('Q')<CR>0f i
    imap <silent><buffer>R :python quicksilver.update('R')<CR>0f i
    imap <silent><buffer>S :python quicksilver.update('S')<CR>0f i
    imap <silent><buffer>T :python quicksilver.update('T')<CR>0f i
    imap <silent><buffer>U :python quicksilver.update('U')<CR>0f i
    imap <silent><buffer>V :python quicksilver.update('V')<CR>0f i
    imap <silent><buffer>W :python quicksilver.update('W')<CR>0f i
    imap <silent><buffer>X :python quicksilver.update('X')<CR>0f i
    imap <silent><buffer>Y :python quicksilver.update('Y')<CR>0f i
    imap <silent><buffer>Z :python quicksilver.update('Z')<CR>0f i
endfunction "}}} 
function! s:Highlight() "{{{
    hi link Suggestion  Comment
    match Suggestion    /\[[^\]]*\]/
endfunction "}}}
function! s:ActivateQS() "{{{
    execute 'bo 1 new __Quicksilver__'
    python quicksilver.clear()
    call s:MapKeys()
    call s:Highlight()
endfunction "}}}
"{{{ Map <leader>q to ActivateQS
if !hasmapto("<SID>ActivateQS")
    map <unique><leader>q :call <SID>ActivateQS()<CR>0f i
endif
"}}}
"}}}
" vim:fdm=marker
