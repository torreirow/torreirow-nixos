set nocompatible
syntax on
filetype plugin indent on

call plug#begin('~/.local/share/nvim/plugged')
  Plug 'preservim/nerdtree'
  Plug 'junegunn/fzf.vim'
  Plug 'junegunn/fzf'
  Plug 'hashivim/vim-terraform'
  Plug 'LnL7/vim-nix'
  Plug 'luizribeiro/vim-cooklang', { 'for': 'cook' }
  Plug 'ayu-theme/ayu-vim' 
  Plug 'linden-project/linny.vim' 
  Plug 'mipmip/vim-hotpop' 
  Plug 'vim-pandoc/vim-pandoc-syntax'  " Vereiste plugin voor syntax
  Plug 'quarto-dev/quarto-vim', { 'for': 'quarto' }
call plug#end()

nmap ,, :NERDTreeFind <CR>
nmap ,/ :Ag 
nmap ,\ :Rg 
nmap ,b :Buffers
nmap ,f :Files
nmap ,n :NERDTree <CR>
set hlsearch    " highlight matches
set ignorecase  " searches are case insensitive...
set smartcase   " ... unless they contain at least one capital letter
set belloff=all
autocmd FileType qmd, tf, yaml,yml,markdown setlocal expandtab tabstop=2 shiftwidth=2
set tabstop=2
set shiftwidth=2
set expandtab
silent !mkdir -p ~/.vim_temp/undodir > /dev/null 2>&1
set undofile " Maintain undo history between sessions
set undodir=~/.vim_temp/undodir
let NERDTreeShowBookmarks=1
let NERDTreeShowHidden=1
let NERDTreeIgnore = ['^\.DS_Store$', '\.dat.nosync', '\.swp', '\.repl_history', '\.cxx', '\.cxx_parameters' ]
let NERDTreeChDirMode=2
"let g:NERDTreeWinSize=50
let NERDTreeAutoDeleteBuffer = 1
let NERDTreeMinimalUI = 0
set termguicolors     " enable true colors support
let ayucolor="dark"   " for dark
colorscheme ayu
autocmd BufNewFile,BufRead *.qmd set filetype=markdown


let g:linny_open_notebook_path       = $HOME . '/data/git/torreirow/torrlinny'
call linny#Init()

