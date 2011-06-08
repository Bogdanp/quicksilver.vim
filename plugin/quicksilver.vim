" =======================================================================
" File:        quicksilver.vim
" Version:     0.3.0
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

from glob import glob

class Quicksilver(object):
    def __init__(self, match_fn='normal'):
        self.set_match_fn(match_fn)
        self.cwd = '{0}/'.format(os.getcwd())
        self.ignore_case = True
        self.match_index = 0

    def _cmp_files(self, x, y):
        "Files not starting with '.' come first."
        if x[0] == '.' and y[0] != '.': return 1
        if x[0] != '.' and y[0] == '.': return -1
        else: return cmp(x, y)

    def set_ignore_case(self, value):
        try: self.ignore_case = int(value)
        except ValueError: self.ignore_case = True

    def toggle_ignore_case(self):
        self.ignore_case = not self.ignore_case
        self.update()

    def normalize_case(self, filename):
        pattern = self.pattern
        if self.ignore_case:
            return pattern.lower(), filename.lower()
        return pattern, filename

    def fuzzy_match(self, filename):
        pattern, filename = self.normalize_case(filename)
        return set(pattern).issubset(set(filename))

    def normal_match(self, filename):
        pattern, filename = self.normalize_case(filename)
        return pattern in filename

    def set_match_fn(self, fn):
        try:
            self.match_fn = {
                'fuzzy': self.fuzzy_match,
                'normal': self.normal_match,
            }[fn]
        except KeyError:
            self.match_fn = self.normal_match

    def set_fuzzy_matching(self):
        self.set_match_fn('fuzzy')
        self.update()

    def set_normal_matching(self):
        self.set_match_fn('normal')
        self.update()

    def get_files(self):
        for f in os.listdir(self.cwd):
            path = os.path.join(self.cwd, f)
            yield '{0}/'.format(f) if os.path.isdir(path) else f

    def index_files(self, files):
        """Returns a list of files with the item at index
        'matched_index' at the front."""
        try:
            current = [files[self.match_index]]
            up_to_current = files[:self.match_index]
            after_current = files[self.match_index + 1:]
            return current + after_current + up_to_current
        except IndexError:
            self.match_index = 0
            return files

    def decrease_index(self):
        if self.match_index > 0:
            self.match_index -= 1
        self.update(cmi=False)

    def increase_index(self):
        self.match_index += 1
        self.update(cmi=False)

    def reset_match_index(self):
        self.match_index = 0

    def match_files(self):
        files = sorted([f for f in self.get_files() if self.match_fn(f)],
                       cmp=self._cmp_files)
        if not self.pattern and self.cwd != '/':
            files.insert(0, '../')
        return self.index_files(files)

    def get_matched_file(self):
        return self.match_files()[0]

    def clear(self):
        self.pattern = ''
        self.update()

    def clear_character(self):
        self.pattern = self.pattern[:-1]
        self.update()

    def clear_pattern(self):
        if not self.pattern:
            self.cwd = self.get_up_dir(self.cwd + '/')
        self.pattern = ''
        self.update()

    def close_buffer(self):
        vim.command('{0} wincmd w'.format(
            vim.eval('bufwinnr("__Quicksilver__")')
        ))
        vim.command('bd!')

    def glob_paths(self):
        paths = []
        for path in glob(self.rel(self.pattern)):
            if not os.path.isdir(path):
                paths.append(self.rel(path))
        return paths

    def get_up_dir(self, path):
        self.reset_match_index()
        return '/'.join(path.split('/')[:-3]) + '/'

    def rel(self, path):
        return self.sanitize_path(os.path.join(self.cwd, path))

    def sanitize_path(self, path):
        return path.replace(' ', '\ ')

    def get_cursor_location(self):
        return len(self.rel(self.pattern)) + 1

    def update_cursor(self):
        vim.command('normal gg')
        vim.command('normal {0}|'.format(self.get_cursor_location()))
        vim.command('startinsert')

    def update(self, c='', cmi=True):
        if cmi: self.matched_index = 0
        self.pattern += c
        files_string = ' | '.join(f for f in self.match_files())
        vim.command('normal ggdG')
        vim.current.line = '{0}{1} {{{2}}}'.format(
            self.cwd, self.pattern, files_string
        )
        self.update_cursor()

    def build_path(self):
        try:
            path = self.rel(self.get_matched_file())
            if self.get_matched_file() == '../':
                return self.get_up_dir(path)
        except IndexError:
            path = self.rel(self.pattern)
            if self.pattern.endswith('/'): os.mkdir(path)
            if self.pattern.startswith('*')\
            or self.pattern.endswith('*'):
                return self.glob_paths()
        return path

    def open_list(self, paths):
        self.close_buffer()
        for path in paths:
            vim.command('edit {0}'.format(path))

    def open_dir(self, path):
        self.cwd = path
        self.clear()
        self.update_cursor()

    def open_file(self, path):
        self.close_buffer()
        vim.command('edit {0}'.format(path))

    def open(self):
        path = self.build_path()
        self.reset_match_index()
        if isinstance(path, list): self.open_list(path)
        elif os.path.isdir(path): self.open_dir(path)
        else: self.open_file(path)
EOF
"}}}
"{{{ Public interface
"{{{ Initialize Quicksilver object
if exists('g:QSMatchFn')
    python quicksilver = Quicksilver(vim.eval('g:QSMatchFn'))
else
    python quicksilver = Quicksilver()
endif
"}}}
function! s:MapKeys() "{{{
    imap <silent><buffer><SPACE> :python quicksilver.update(' ')<CR>
    map  <silent><buffer><C-c> :python quicksilver.close_buffer()<CR>
    imap <silent><buffer><C-c> :python quicksilver.close_buffer()<CR>
    imap <silent><buffer><C-w> :python quicksilver.clear_pattern()<CR>
    map  <silent><buffer><C-f> :python quicksilver.set_fuzzy_matching()<CR>
    imap <silent><buffer><C-f> :python quicksilver.set_fuzzy_matching()<CR>
    map  <silent><buffer><C-n> :python quicksilver.set_normal_matching()<CR>
    imap <silent><buffer><C-n> :python quicksilver.set_normal_matching()<CR>
    map  <silent><buffer><C-t> :python quicksilver.toggle_ignore_case()<CR>
    imap <silent><buffer><C-t> :python quicksilver.toggle_ignore_case()<CR>
    map  <silent><buffer><TAB> :python quicksilver.increase_index()<CR>
    imap <silent><buffer><TAB> :python quicksilver.increase_index()<CR>
    map  <silent><buffer><S-TAB> :python quicksilver.decrease_index()<CR>
    imap <silent><buffer><S-TAB> :python quicksilver.decrease_index()<CR>
    imap <silent><buffer><BAR> :python quicksilver.update('\|')<CR>
    map  <silent><buffer><CR> :python quicksilver.open()<CR>
    imap <silent><buffer><CR> :python quicksilver.open()<CR>
    imap <silent><buffer><BS> :python quicksilver.clear_character()<CR>
    imap <silent><buffer>! :python quicksilver.update('!')<CR>
    imap <silent><buffer>" :python quicksilver.update('"')<CR>
    imap <silent><buffer># :python quicksilver.update('#')<CR>
    imap <silent><buffer>$ :python quicksilver.update('$')<CR>
    imap <silent><buffer>% :python quicksilver.update('%')<CR>
    imap <silent><buffer>& :python quicksilver.update('&')<CR>
    imap <silent><buffer>' :python quicksilver.update(''')<CR>
    imap <silent><buffer>( :python quicksilver.update('(')<CR>
    imap <silent><buffer>) :python quicksilver.update(')')<CR>
    imap <silent><buffer>* :python quicksilver.update('*')<CR>
    imap <silent><buffer>+ :python quicksilver.update('+')<CR>
    imap <silent><buffer>, :python quicksilver.update(',')<CR>
    imap <silent><buffer>- :python quicksilver.update('-')<CR>
    imap <silent><buffer>. :python quicksilver.update('.')<CR>
    imap <silent><buffer>/ :python quicksilver.update('/')<CR>
    imap <silent><buffer>0 :python quicksilver.update('0')<CR>
    imap <silent><buffer>1 :python quicksilver.update('1')<CR>
    imap <silent><buffer>2 :python quicksilver.update('2')<CR>
    imap <silent><buffer>3 :python quicksilver.update('3')<CR>
    imap <silent><buffer>4 :python quicksilver.update('4')<CR>
    imap <silent><buffer>5 :python quicksilver.update('5')<CR>
    imap <silent><buffer>6 :python quicksilver.update('6')<CR>
    imap <silent><buffer>7 :python quicksilver.update('7')<CR>
    imap <silent><buffer>8 :python quicksilver.update('8')<CR>
    imap <silent><buffer>9 :python quicksilver.update('9')<CR>
    imap <silent><buffer>: :python quicksilver.update(':')<CR>
    imap <silent><buffer>; :python quicksilver.update(';')<CR>
    imap <silent><buffer>< :python quicksilver.update('<')<CR>
    imap <silent><buffer>= :python quicksilver.update('=')<CR>
    imap <silent><buffer>> :python quicksilver.update('>')<CR>
    imap <silent><buffer>? :python quicksilver.update('?')<CR>
    imap <silent><buffer>@ :python quicksilver.update('@')<CR>
    imap <silent><buffer>A :python quicksilver.update('A')<CR>
    imap <silent><buffer>B :python quicksilver.update('B')<CR>
    imap <silent><buffer>C :python quicksilver.update('C')<CR>
    imap <silent><buffer>D :python quicksilver.update('D')<CR>
    imap <silent><buffer>E :python quicksilver.update('E')<CR>
    imap <silent><buffer>F :python quicksilver.update('F')<CR>
    imap <silent><buffer>G :python quicksilver.update('G')<CR>
    imap <silent><buffer>H :python quicksilver.update('H')<CR>
    imap <silent><buffer>I :python quicksilver.update('I')<CR>
    imap <silent><buffer>J :python quicksilver.update('J')<CR>
    imap <silent><buffer>K :python quicksilver.update('K')<CR>
    imap <silent><buffer>L :python quicksilver.update('L')<CR>
    imap <silent><buffer>M :python quicksilver.update('M')<CR>
    imap <silent><buffer>N :python quicksilver.update('N')<CR>
    imap <silent><buffer>O :python quicksilver.update('O')<CR>
    imap <silent><buffer>P :python quicksilver.update('P')<CR>
    imap <silent><buffer>Q :python quicksilver.update('Q')<CR>
    imap <silent><buffer>R :python quicksilver.update('R')<CR>
    imap <silent><buffer>S :python quicksilver.update('S')<CR>
    imap <silent><buffer>T :python quicksilver.update('T')<CR>
    imap <silent><buffer>U :python quicksilver.update('U')<CR>
    imap <silent><buffer>V :python quicksilver.update('V')<CR>
    imap <silent><buffer>W :python quicksilver.update('W')<CR>
    imap <silent><buffer>X :python quicksilver.update('X')<CR>
    imap <silent><buffer>Y :python quicksilver.update('Y')<CR>
    imap <silent><buffer>Z :python quicksilver.update('Z')<CR>
    imap <silent><buffer>[ :python quicksilver.update('[')<CR>
    imap <silent><buffer>\ :python quicksilver.update('\\')<CR>
    imap <silent><buffer>] :python quicksilver.update(']')<CR>
    imap <silent><buffer>^ :python quicksilver.update('^')<CR>
    imap <silent><buffer>_ :python quicksilver.update('_')<CR>
    imap <silent><buffer>` :python quicksilver.update('`')<CR>
    imap <silent><buffer>a :python quicksilver.update('a')<CR>
    imap <silent><buffer>b :python quicksilver.update('b')<CR>
    imap <silent><buffer>c :python quicksilver.update('c')<CR>
    imap <silent><buffer>d :python quicksilver.update('d')<CR>
    imap <silent><buffer>e :python quicksilver.update('e')<CR>
    imap <silent><buffer>f :python quicksilver.update('f')<CR>
    imap <silent><buffer>g :python quicksilver.update('g')<CR>
    imap <silent><buffer>h :python quicksilver.update('h')<CR>
    imap <silent><buffer>i :python quicksilver.update('i')<CR>
    imap <silent><buffer>j :python quicksilver.update('j')<CR>
    imap <silent><buffer>k :python quicksilver.update('k')<CR>
    imap <silent><buffer>l :python quicksilver.update('l')<CR>
    imap <silent><buffer>m :python quicksilver.update('m')<CR>
    imap <silent><buffer>n :python quicksilver.update('n')<CR>
    imap <silent><buffer>o :python quicksilver.update('o')<CR>
    imap <silent><buffer>p :python quicksilver.update('p')<CR>
    imap <silent><buffer>q :python quicksilver.update('q')<CR>
    imap <silent><buffer>r :python quicksilver.update('r')<CR>
    imap <silent><buffer>s :python quicksilver.update('s')<CR>
    imap <silent><buffer>t :python quicksilver.update('t')<CR>
    imap <silent><buffer>u :python quicksilver.update('u')<CR>
    imap <silent><buffer>v :python quicksilver.update('v')<CR>
    imap <silent><buffer>w :python quicksilver.update('w')<CR>
    imap <silent><buffer>x :python quicksilver.update('x')<CR>
    imap <silent><buffer>y :python quicksilver.update('y')<CR>
    imap <silent><buffer>z :python quicksilver.update('z')<CR>
    imap <silent><buffer>{ :python quicksilver.update('{')<CR>
    imap <silent><buffer>} :python quicksilver.update('}')<CR>
    imap <silent><buffer>~ :python quicksilver.update('~')<CR>
endfunction "}}} 
function! s:HighlightSuggestions() "{{{
    hi link Suggestions  Special
    match Suggestions    /\s{[^}]*}/
endfunction "}}}
function! s:SetIgnoreCase(value) "{{{
    python quicksilver.set_ignore_case(vim.eval('a:value'))
endfunction "}}}
function! s:SetMatchFn(type) "{{{
    python quicksilver.set_match_fn(vim.eval('a:type'))
endfunction "}}}
function! s:ActivateQS() "{{{
    execute 'bo 2 new __Quicksilver__'
    python quicksilver.clear()
    setlocal wrap
    call s:MapKeys()
    call s:HighlightSuggestions()
endfunction "}}}
"{{{ Map <leader>q to ActivateQS
if !hasmapto("<SID>ActivateQS")
    map <unique><leader>q :call <SID>ActivateQS()<CR>
endif
"}}}
"{{{ Expose public functions
command! -nargs=0 QSActivate   call s:QSActivate()
command! -nargs=1 QSSetIC      call s:SetIgnoreCase(<args>)
command! -nargs=1 QSSetMatchFn call s:SetMatchFn(<args>)
"}}}
"}}}
" vim:fdm=marker
