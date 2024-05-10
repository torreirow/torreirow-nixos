{config,pkgs,services,...}: {
 programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
 programs.jq = {
    enable = true;
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

  programs.rbw = {
    enable = true;
    settings = {
      base_url = "https://homeassistant.toorren.net:7277";
      email = "wvdtoorren@gmail.com";
    };
  };

 
 programs.home-manager.enable = true;
 home.stateVersion = "23.11";
 home.username = "wtoorren";

}
