{config,pkgs,...}: {
 programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

 programs.home-manager.enable = true;
 home.stateVersion = "23.11";
 home.username = "wtoorren";

 imports = [
  ./awsconf.nix
 ];

}
