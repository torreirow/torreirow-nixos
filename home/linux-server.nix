{config,pkgs,...}: {
 
 imports = [
  ./zsh.nix
  ./common.nix
  ./awsconf.nix
  ./dotfiles
  ./vim.nix
  ./tmux.nix
  ./sshkeys.nix
 ];

}
