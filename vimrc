set nocompatible
filetype off

set shell=bash

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'gmarik/Vundle.vim'

Plugin 'vim-ruby/vim-ruby'
Plugin 'tpope/vim-endwise'
Plugin 'jelera/vim-javascript-syntax'
Plugin 'mxw/vim-jsx'
Plugin 'pangloss/vim-javascript'
Plugin 'kchmck/vim-coffee-script'
Plugin 'tpope/vim-rake'
Plugin 'vim-scripts/matchit.zip'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'slim-template/vim-slim'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-commentary'
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'garbas/vim-snipmate'
Plugin 'honza/vim-snippets'
Plugin 'airblade/vim-gitgutter'
Plugin 'nelstrom/vim-textobj-rubyblock'
Plugin 'kana/vim-textobj-user'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-repeat'
Plugin 'xolox/vim-misc'
Plugin 'mileszs/ack.vim'
Plugin 'bling/vim-airline'
Plugin 'majutsushi/tagbar'
Plugin 'ervandew/supertab'
Plugin 'Raimondi/delimitMate'
Plugin 'rking/ag.vim'
Plugin 'wavded/vim-stylus'
Plugin 'Shutnik/jshint2.vim'
Plugin 'vim-scripts/Gundo'
Plugin 'elixir-lang/vim-elixir'
Plugin 'xolox/vim-easytags'

call vundle#end()
filetype plugin indent on

set backspace=2
set ruler         " show the cursor position all the time
set showcmd       " display incomplete commands

set nowrap " avoid line wrapping
set hlsearch " highlight search results
set incsearch " show search results while typing
setlocal ignorecase " ignore case when searching
setlocal smartcase " when searching try to be smart about cases
set cursorline " show cursor line

let g:easytags_async = 1
let g:easytags_auto_highlight = 0

let mapleader = "\<Space>"

" clean the current search
nmap <leader>h :nohlsearch<cr>

" handy shortcuts
map - dd

" adopt new ruby hash syntax
" :%s/:\([^ ]*\)\(\s*\)=>/\1:/g
" :%s/:(\w+)(\s*)=>/\1:/g

" master fucking undo
set undodir=~/.cache/undodir
set undofile
nnoremap <F5> :GundoToggle<CR>

set clipboard+=unnamed

" autoread files that were changed outside of vim
set autoread

set number
set relativenumber

set ttyfast
set ttyscroll=3
set lazyredraw

" use 2 spaces instead of tabs
set expandtab
set smarttab
set tabstop=2
set shiftwidth=2

" use natural screen spliting
set splitbelow
set splitright

set guifont=Hack:h18

" Make it obvious where 80 characters is
set textwidth=65
set colorcolumn=+1

" disable backup files
set nobackup
set nowb
set noswapfile

" disable scrollbars
set guioptions-=r
set guioptions-=R
set guioptions-=l
set guioptions-=L

" always horizontally center search results
nmap n nzz
nmap N Nzz

colorscheme railscasts

" remap 0 in normal mode to go to the beginning of the text line
nmap 0 ^

nmap <leader>p :CtrlP<cr>
let g:fuzzy_ignore = "*.png;*.PNG;*.JPG;*.jpg;*.GIF;*.gif;;coverage/**;tmp/**;rdoc/**"
let g:ctrlp_custom_ignore = 'node_modules\|bower_components\|DS_Store\|git\|doc\|tags'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_max_height = 12

let jshint2_save = 1

if executable('ag')
  " Use ag over grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'

  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif

nnoremap K :grep! "\b<C-R><C-W>\b"<CR>:cw<CR>

" navigate through panes with ctrl + hjkl
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
nmap <leader>t :TagbarToggle<CR>

let g:notes_directories = ['~/Dropbox/notes']

" Automatically wrap at 72 characters and spell check git commit messages
autocmd FileType gitcommit setlocal textwidth=72
autocmd FileType gitcommit setlocal spell
" activate spell checking on Markdown files
autocmd BufRead,BufNewFile *.md setlocal spell
" enable word autocompletion
set complete+=kspell

au BufRead,BufNewFile *.hbs setfiletype html
au BufRead,BufNewFile *.es6 setfiletype javascript
au BufRead,BufNewFile *.jbuilder setfiletype ruby

" Tab completion
" " will insert tab at beginning of line,
" " will use completion if not at beginning
set wildmode=list:longest,list:full
function! InsertTabWrapper()
  let col = col('.') - 1
  if !col || getline('.')[col - 1] !~ '\k'
    return "\<tab>"
  else
    return "\<c-p>"
  endif
endfunction
inoremap <Tab> <c-r>=InsertTabWrapper()<cr>
inoremap <S-Tab> <c-n>

let g:airline_powerline_fonts = 1
function! AirlineInit()
  let g:airline_section_a = airline#section#create(['mode', ' ', 'branch'])
  let g:airline_section_b = airline#section#create_left(['hunks', '%f'])
  let g:airline_section_c = airline#section#create(['filetype'])
  let g:airline_section_x = airline#section#create(['%P'])
  let g:airline_section_y = airline#section#create(['%B'])
  let g:airline_section_z = airline#section#create_right(['%l', '%c'])
endfunction
autocmd VimEnter * call AirlineInit()
set laststatus=2

" Removes trailing spaces
function! TrimWhiteSpace()
  %s/\s\+$//e
endfunction

nnoremap <silent> <Leader>rts :call TrimWhiteSpace()<CR>
autocmd FileWritePre    * :call TrimWhiteSpace()
autocmd FileAppendPre   * :call TrimWhiteSpace()
autocmd FilterWritePre  * :call TrimWhiteSpace()
autocmd BufWritePre     * :call TrimWhiteSpace()

vmap <Leader>b :<C-U>!git blame <C-R>=expand("%:p") <CR> \| sed -n <C-R>=line("'<") <CR>,<C-R>=line("'>") <CR>p <CR>
