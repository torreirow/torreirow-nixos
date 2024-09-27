{config,pkgs,...}: {

programs.vim.plugins = [
  pkgs.vimPlugins.nerdtree
  pkgs.vimPlugins.fzf-vim
  pkgs.vimPlugins.vim-terraform
  pkgs.vimPlugins.vim-nix
  pkgs.vimPlugins.nvim-treesitter-parsers.cooklang
  pkgs.vimPlugins.ayu-vim

### VIM PLUG TODO
#  pkgs.vimPlugins.vim-plug
#  runtime! plug.vim
#  call plug#begin('~/.vim/plugged')
#    Plug 'mipmip/vim-hotpop.vim'
#  call plug#end()


]; 

programs.vim.enable = true;
programs.vim.defaultEditor = true;
programs.vim.extraConfig = ''
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
'';


}
