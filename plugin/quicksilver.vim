" =======================================================================
" File:        quicksilver.vim
" Version:     0.4.6
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
if !exists("g:QSIgnore")
    let g:QSIgnore = ""
endif
let g:loaded_quicksilver = 1
"}}}
"{{{ Python code
python <<EOF
import glob
import os
import re
import sys
import vim

class QuicksilverConst(object):
    # Users may set a global variable containing regexps of filenames that
    # should be ignored. For example, to ignore .pyc and .swp files, one
    # could add the following line to their .vimrc file:
    #   let g:QSIgnore = "\\.pyc$;\\.swp$"
    #
    # This feature was inspired by obmarg's (https://github.com/obmarg) fork.
    USER_IGNORED = vim.eval("g:QSIgnore").split(";")

    # Since g:QSIgnore might be empty USER_IGNORED could take the form ['']
    # which is something we don't want since the empty string regexp will match
    # all filenames. This accounts for that special case.
    if len(USER_IGNORED) == 1 and not USER_IGNORED[0]:
        USER_IGNORED = []

    # Files and folders that should never appear in the list of matches.
    IGNORED = ["^\\$Recycle\\.Bin$", ".*\\.sw*"] + USER_IGNORED
    
    # Platform-specific root directories.
    if sys.platform == "win32":
        ROOTS = ["{0}:\\".format(chr(drive)) for drive in range(ord("A"), ord("Z"))]
    else:
        ROOTS = (os.sep,)

    # The string by which the matches should be separated.
    SEPARATOR = " | "

    # When this string is selected from the matches, quicksilver must go up a dir.
    UPDIR = "..{0}".format(os.sep)

class QuicksilverUtil(object):
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
        "Changes the VIM working dir to the given path."
        vim.command("cd {0}".format(path))

    @classmethod
    def is_ignored(cls, filename):
        "Matches the given filename against a blacklist of regexps."
        for pattern in QuicksilverConst.IGNORED:
            if re.match(pattern, filename):
                return True
        return False

    @classmethod
    def is_updir(cls, filename):
        "Checks whether or not the given filename is the updir string."
        return filename == QuicksilverConst.UPDIR

class QuicksilverMatcher(object):
    @classmethod
    def fuzzy(cls, qs, filename):
        """Applies an ordered fuzzy match on the given filename.
        Given the pattern "rdm", it matches "Readme.md" but not "Remade"."""
        pattern, filename = qs.normalize_case(filename)
        for item in pattern:
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
        self.index = 0

    def change_drive(self, drive):
        "Change the drive on Windows systems."
        drive = "{0}:\\".format(drive.upper())
        if sys.platform != 'win32' \
        or not os.path.isdir(drive):
            return
        self.clear()
        self.cwd = drive
        self.update()

    def set_ignore_case(self, ignore_case):
        "Setter for the ignore_case property."
        try: self.ignore_case = int(ignore_case)
        except ValueError: self.ignore_case = True

    def toggle_ignore_case(self):
        "Toggles the value of the ignore_case property."
        self.ignore_case = not self.ignore_case
        self.update()

    def rel(self, path):
        """Joins the given path together with the CWD and sanitizes the
        resulting path."""
        return self.sanitize_path(os.path.join(self.cwd, path))

    def get_parent(self, path):
        "Returns the parent directory of the CWD."
        self.index = 0
        return os.sep.join(path.split(os.sep)[:-3]) + os.sep

    def normalize_case(self, filename):
        """Normalizes the character case for the pattern and the given filename
        based the value of ignore_case."""
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
            if QuicksilverUtil.is_ignored(filename): continue
            if os.path.isdir(self.rel(filename)):
                filename = "{0}{1}".format(filename, os.sep)
            files.append(filename)
        return sorted(files, cmp=QuicksilverUtil.compare_files)

    def match_files(self):
        "Gets and indexes the matched files."
        files = self.get_files()
        if not self.pattern and self.cwd.upper() not in QuicksilverConst.ROOTS:
            files.insert(0, QuicksilverConst.UPDIR)
        return self.index_files(files)

    def get_matched_file(self):
        "Returns the top match for the current pattern."
        return self.match_files()[0]

    def index_files(self, files):
        """Returns a list of files with the item at index 'matched_index' at
        the front."""
        try:
            current = [files[self.index]]
            up_to_current = files[:self.index]
            after_current = files[self.index + 1:]
            return current + after_current + up_to_current
        except IndexError:
            self.index = 0
            return files

    def decrease_index(self):
        """(On S-Tab) decreases the match index and calls update so that the
        changes are visible in the match list."""
        if self.index > 0:
            self.index -= 1
        self.update()

    def increase_index(self):
        """(On Tab) increases the match index and calls update so that the
        changes are visible in the match list."""
        self.index += 1
        self.update()

    def on_backspace(self):
        "Removes the last character in the pattern and redraws the buffer."
        self.pattern = self.pattern[:-1]
        self.update()

    def clear(self):
        "Clears the pattern and redraws the buffer."
        self.pattern = ""
        self.update()

    def clear_pattern(self):
        """Similar to a normal clear but it also goes up a dir if there is no
        pattern to clear."""
        if not self.pattern and not self.cwd in QuicksilverConst.ROOTS:
            self.cwd = self.get_parent(self.cwd + os.sep)
        self.clear()

    def glob(self, pattern):
        """Globs the given pattern and returns the paths of all the files that
        match."""
        for path in glob.glob(pattern):
            if not os.path.isdir(path):
                yield self.rel(path)

    def sanitize_path(self, path):
        "Sanitize the path for UNIX systems."
        if sys.platform == "win32":
            return path
        return path.replace(" ", "\\ ")

    def update(self, character=""):
        """Add the given character to the pattern and "redraw" the path and
        matches."""
        self.pattern += character
        vim.current.line = "{0}{1} {{{2}}}".format(
            self.cwd, self.pattern,
            QuicksilverConst.SEPARATOR.join(self.match_files())
        )
        QuicksilverUtil.update_cursor(self)

    def build_path(self):
        "Builds the target path using the CWD and the pattern."
        try:
            filename = self.get_matched_file()
            path = self.rel(filename)
            if QuicksilverUtil.is_updir(filename):
                return self.get_parent(path)
            return path
        except IndexError:
            # The file does not exist.
            path = self.rel(self.pattern)
            if self.pattern.endswith(os.sep):
                os.mkdir(path)
            if self.pattern.startswith("*") \
            or self.pattern.endswith("*"):
                return list(self.glob(path))
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
        self.index = 0
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
    imap <silent><buffer><BS> :python quicksilver.on_backspace()<CR>
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
    hi link Suggestions Special
    match Suggestions   /\s*{[^}]*}/
endfunction "}}}
function! s:SetIgnoreCase(value) "{{{
    python quicksilver.set_ignore_case(vim.eval('a:value'))
endfunction "}}}
function! s:SetMatchFn(type) "{{{
    python quicksilver.set_matcher(vim.eval('a:type'))
endfunction "}}}
function! s:ChangeDrive() "{{{
    python quicksilver.change_drive(vim.eval('input("Enter a drive letter: ")'))
endfunction "}}}
function! s:ActivateQS() "{{{
    let g:QSRestoreWindows = winrestcmd()
    execute 'bo 2 new'
    setlocal buftype=nofile
    setlocal wrap
    python quicksilver.clear()
    call s:MapKeys()
    call s:HighlightSuggestions()
endfunction "}}}
"{{{ Map <leader>q to ActivateQS
if !hasmapto("<SID>ActivateQS")
    map <unique><leader>q :call <SID>ActivateQS()<CR>
endif
"}}}
"{{{ Expose public functions
command! -nargs=0 QSActivate    call s:ActivateQS()
command! -nargs=1 QSSetIC       call s:SetIgnoreCase(<args>)
command! -nargs=1 QSSetMatchFn  call s:SetMatchFn(<args>)
command! -nargs=0 QSChangeDrive call s:ChangeDrive()
"}}}
"}}}
" vim:fdm=marker
