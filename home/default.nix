{config,pkgs,...}: {
 programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

 programs.home-manager.enable = true;
 home.stateVersion = "23.11";

 imports = [
  ./awsconf.nix
 ];

}
