{config,pkgs,...}: {
 imports = [
  ./zsh.nix
  ./awsconf.nix
  ./common.nix
  ./vim.nix
 ];

}
