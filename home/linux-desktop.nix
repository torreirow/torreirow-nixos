{config,pkgs,...}: {
 imports = [
  ./zsh.nix
  ./awsconf.nix
  ./tmux.nix
  ./common.nix
  ./vim.nix
  ./dotfiles
  ./gnome-desktop
  ./librewolf.nix
#  ./sshkeys.nix
#  ./dotfiles/toggl-secret.nix
];

#services.flameshot= {
#  enable = true;
#  settings = {
#    General = {
#      disabledTrayIcon = false;
#      showStartupLaunchMessage = true;
#    };
#  };
#
#};

}
