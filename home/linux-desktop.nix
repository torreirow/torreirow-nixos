{config,pkgs,...}: {
 imports = [
  ./zsh.nix
  #./awsconf.nix
  ./common.nix
  ./vim.nix
  ./dotfiles
  ./tmux.nix
  ./gnome-desktop
#  ./dotfiles/toggl-secret.nix
];

}
