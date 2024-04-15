{config,pkgs,...}: {

programs.vim.plugins = [
  pkgs.vimPlugins.nerdtree
  pkgs.vimPlugins.fzf-vim
  pkgs.vimPlugins.vim-terraform
  pkgs.vimPlugins.vim-nix
]; 

programs.vim.enable = true;
programs.vim.extraConfig = ''
nmap ,, :NERDTreeFind <CR>
'';


}
