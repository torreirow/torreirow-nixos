{config,pkgs,...}: {

programs.vim.plugins = [
  pkgs.vimPlugins.nerdtree
]; 

programs.vim.enable = true;

}
