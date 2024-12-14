{config,pkgs,...}: {
 
 imports = [
  ./zsh.nix
  ./common.nix
  ./dotfiles
  ./vim.nix
 ];

}
