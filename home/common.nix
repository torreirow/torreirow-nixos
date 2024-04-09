{config,pkgs,...}: {
 programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
 programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = [
      "--disable-up-arrow"
    ];
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
    };
 };

 
 
 programs.home-manager.enable = true;
 home.stateVersion = "23.11";
 home.username = "wtoorren";

}
