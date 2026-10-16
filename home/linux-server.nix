{config,pkgs,...}: {
 
 imports = [
  ./zsh.nix
  ./common.nix
  ./awsconf.nix
  ./dotfiles
  ./vim.nix
  ./tmux.nix
  ./module/ssh-config_hosts
  ./module/clipbridge
  ./module/vaultwarden-restore-test
  ./module/wake-bobadela1
  ./module/update-system
  ./sshkeys.nix
 ];

 # Ctrl+V van een afbeelding uit het clipboard van lobos in Claude Code
 # (module: home/module/clipbridge; tunnel staat aan de lobos-kant).
 services.clipbridge.shim.enable = true;

}
