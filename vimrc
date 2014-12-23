set nocompatible
filetype off

set shell=bash

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'gmarik/Vundle.vim'

Plugin 'kchmck/vim-coffee-script'
Plugin 'vim-ruby/vim-ruby'
Plugin 'tpope/vim-rake'
Plugin 'tpope/vim-bundler'
Plugin 'vim-scripts/matchit.zip'
Plugin 'mattn/emmet-vim'
Plugin 'slim-template/vim-slim'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'scrooloose/nerdcommenter'
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'garbas/vim-snipmate'
Plugin 'honza/vim-snippets'
Plugin 'airblade/vim-gitgutter'
Plugin 'nelstrom/vim-textobj-rubyblock'
Plugin 'kana/vim-textobj-user'
Plugin 'tpope/vim-surround'
Plugin 'xolox/vim-misc'
Plugin 'xolox/vim-notes'
Plugin 'mileszs/ack.vim'
Plugin 'bling/vim-airline'
Plugin 'majutsushi/tagbar'
Plugin 'ervandew/supertab'

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
set so=7 " cursor padding

" clean the current search
nmap <leader>h :nohlsearch<cr>

" master fucking undo
set undodir=/tmp/undodir
set undofile

set autoread " autoread files that were changed outside of vim

set number
set relativenumber

" use 2 spaces instead of tabs
set expandtab
set smarttab
set tabstop=2
set shiftwidth=2

" use natural screen spliting
set splitbelow
set splitright

set guifont=Monaco:h20

" Make it obvious where 80 characters is
set textwidth=80
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

colorscheme railscasts

nmap <leader>p :CtrlP<cr>
let g:fuzzy_ignore = "*.png;*.PNG;*.JPG;*.jpg;*.GIF;*.gif;;coverage/**;tmp/**;rdoc/**"
let g:ctrlp_custom_ignore = 'node_modules\|bower_components\|DS_Store\|git\|doc\|tags'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_max_height = 12

nmap <leader>t :TagbarToggle<CR>

let g:notes_directories = ['~/Dropbox/notes']

" Automatically wrap at 72 characters and spell check git commit messages
autocmd FileType gitcommit setlocal textwidth=72
autocmd FileType gitcommit setlocal spell

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

function! AirlineInit()
  let g:airline_section_a = airline#section#create(['mode', ' ', 'branch'])
  let g:airline_section_b = airline#section#create_left(['hunks', '%f'])
  let g:airline_section_c = airline#section#create(['filetype'])
  let g:airline_section_c = airline#section#create(['%P'])
  let g:airline_section_c = airline#section#create(['%B'])
endfunction
autocmd VimEnter * call AirlineInit()

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

