" =======================================================================
" File:        quicksilver.vim
" Version:     0.4.0
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
import sys
import vim

from collections import OrderedDict
from glob import glob

class QuicksilverConst(object):
    # Files and folders that should never appear in the list of matches.
    IGNORED = ("$Recycle.Bin",)
    
    # Platform-specific root directories.
    if sys.platform == "win32":
        ROOTS = ["{0}:\\".format(chr(drive)) for drive in range(ord("A"), ord("Z"))]
    else:
        ROOTS = (os.sep,)

class QuicksilverUtil(object):
    @classmethod
    def ordered_set(cls, string):
        "Builds a fake ordered set."
        return OrderedDict((c, True) for c in string).keys()

    @classmethod
    def compare_files(cls, first, second):
        """Compares two file names so that files that start with a dot are
        heavier than normal files."""
        if first.startswith(".") and not \
           second.startswith("."):
           return 1
        if not first.startswith(".") and \
           second.startswith("."):
           return -1
        return cmp(first, second)

    @classmethod
    def update_cursor(cls, qs):
        "Moves the cursor to the end of the pattern."
        vim.command("normal gg")
        vim.command("normal {0}|".format(len(qs.rel(qs.pattern)) + 1))
        vim.command("startinsert")

    @classmethod
    def close_buffer(cls):
        "Closes the current VIM buffer."
        vim.command("{0} wincmd w".format(
            vim.eval('bufwinnr("__Quicksilver__")')
        ))
        vim.command("bd!")
        vim.command("exe g:QSRestoreWindows")
        vim.command("unlet g:QSRestoreWindows")
        vim.command("wincmd p")

    @classmethod
    def edit(cls, path):
        "Opens the given path for editing."
        vim.command("edit {0}".format(path))

    @classmethod
    def cd(cls, path):
        "Changed the VIM working dir to the given path."
        vim.command("cd {0}".format(path))

class QuicksilverMatcher(object):
    @classmethod
    def fuzzy(cls, qs, filename):
        """Applies an ordered fuzzy match on the given filename.
        Given the pattern "rdm", it matches "Readme.md" but not "Remade.md"."""
        pattern, filename = qs.normalize_case(filename)
        for item in QuicksilverUtil.ordered_set(pattern):
            pos = filename.find(item)
            if filename and pos == -1:
                return False
            filename = filename[pos:]
        return True

    @classmethod
    def normal(cls, qs, filename):
        "Matches any file that contains the pattern."
        pattern, filename = qs.normalize_case(filename)
        return pattern in filename

class Quicksilver(object):
    def __init__(self, matcher='normal'):
        self.set_matcher(matcher)
        self.cwd = "{0}{1}".format(os.getcwd(), os.sep)
        self.ignore_case = True
        self.match_index = 0

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

    def set_matcher(self, function):
        """Given the name of a matcher function to use, it tries to set that
        function as the default; if it fails it falls back to the default
        matcher."""
        try:
            self.matcher = getattr(QuicksilverMatcher, function)
        except AttributeError:
            self.matcher = QuicksilverMatcher.normal

    def get_files(self):
        """Runs the matcher agains every files in the cwd and returns those that
        passed. It also sorts the matched files."""
        files = []
        for filename in os.listdir(self.cwd):
            if not self.matcher(self, filename): continue
            if filename in QuicksilverConst.IGNORED: continue
            if os.path.isdir(self.rel(filename)):
                filename = "{0}{1}".format(filename, os.sep)
            files.append(filename)
        return sorted(files, cmp=QuicksilverUtil.compare_files)

    def match_files(self):
        "Gets and indexes the matched files."
        files = self.get_files()
        if not self.pattern and self.cwd.upper() not in QuicksilverConst.ROOTS:
            files.insert(0, ".." + os.sep)
        return self.index_files(files)

    def get_matched_file(self):
        "Returns the top match for the current pattern."
        return self.match_files()[0]

    def index_files(self, files):
        """Returns a list of files with the item at index 'matched_index' at
        the front."""
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

    def clear(self):
        self.pattern = ""
        self.update()

    def clear_character(self):
        self.pattern = self.pattern[:-1]
        self.update()

    def clear_pattern(self):
        if not self.pattern:
            self.cwd = self.get_parent_dir(self.cwd + os.sep)
        self.pattern = ""
        self.update()

    def glob_paths(self):
        paths = []
        for path in glob(self.rel(self.pattern)):
            if not os.path.isdir(path):
                paths.append(self.rel(path))
        return paths

    def get_parent_dir(self, path):
        self.reset_match_index()
        return os.sep.join(path.split(os.sep)[:-3]) + os.sep

    def rel(self, path):
        return self.sanitize_path(os.path.join(self.cwd, path))

    def sanitize_path(self, path):
        "TODO: Figure out if this is actually needed on Linux at all."
        if sys.platform == "win32":
            return path
        return path.replace(" ", "\\ ")

    def update(self, c="", cmi=True):
        if cmi: self.matched_index = 0
        self.pattern += c
        files_string = " | ".join(f for f in self.match_files())
        vim.command("normal ggdG")
        vim.current.line = "{0}{1} {{{2}}}".format(
            self.cwd, self.pattern, files_string
        )
        QuicksilverUtil.update_cursor(self)

    def build_path(self):
        try:
            path = self.rel(self.get_matched_file())
            if self.get_matched_file() == ".." + os.sep:
                return self.get_parent_dir(path)
        except IndexError:
            path = self.rel(self.pattern)
            if self.pattern.endswith(os.sep):
                os.mkdir(path)
            if self.pattern.startswith("*") \
            or self.pattern.endswith("*"):
                return self.glob_paths()
        return path

    def open_on_tab(self):
        if len(self.match_files()) == 1: self.open()
        else: self.increase_index()

    def open_list(self, paths):
        QuicksilverUtil.close_buffer()
        for path in paths:
            QuicksilverUtil.edit(path)

    def open_dir(self, path):
        self.cwd = path
        self.clear()
        QuicksilverUtil.update_cursor(self)
        QuicksilverUtil.cd(path)

    def open_file(self, path):
        QuicksilverUtil.close_buffer()
        QuicksilverUtil.edit(path)

    def open(self):
        path = self.build_path()
        self.reset_match_index()
        if isinstance(path, list):
            return self.open_list(path)
        if os.path.isdir(path): 
            return self.open_dir(path)
        return self.open_file(path)
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
    map  <silent><buffer><C-c> :python QuicksilverUtil.close_buffer()<CR>
    imap <silent><buffer><C-c> :python QuicksilverUtil.close_buffer()<CR>
    imap <silent><buffer><C-w> :python quicksilver.clear_pattern()<CR>
    map  <silent><buffer><C-f> :python quicksilver.set_matcher("fuzzy")<CR>
    imap <silent><buffer><C-f> :python quicksilver.set_matcher("fuzzy")<CR>
    map  <silent><buffer><C-n> :python quicksilver.set_matcher("normal")<CR>
    imap <silent><buffer><C-n> :python quicksilver.set_matcher("normal")<CR>
    map  <silent><buffer><C-t> :python quicksilver.toggle_ignore_case()<CR>
    imap <silent><buffer><C-t> :python quicksilver.toggle_ignore_case()<CR>
    map  <silent><buffer><TAB> :python quicksilver.open_on_tab()<CR>
    imap <silent><buffer><TAB> :python quicksilver.open_on_tab()<CR>
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
    python quicksilver.set_matcher(vim.eval('a:type'))
endfunction "}}}
function! s:ActivateQS() "{{{
    let g:QSRestoreWindows = winrestcmd()
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
