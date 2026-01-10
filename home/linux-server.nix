{config,pkgs,...}: {
 
 imports = [
  ./zsh.nix
  ./common.nix
  ./awsconf.nix
  ./dotfiles
  ./vim.nix
  ./tmux.nix
  ./module/ssh-config_hosts
  ./sshkeys.nix
 ];

}
