{config,pkgs,services,lib, ...}: 

{

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
      #sync_address = "https://api.atuin.sh";
      sync_address = "https://atuin.tools.technative.cloud";
      search_mode = "fuzzy";
    };
  };

  programs.rbw = {
    enable = true;
#    settings = {
#      base_url = "https://homeassistant.toorren.net:7277";
#      email = "wvdtoorren@gmail.com";
#    };
  };

 
 programs.home-manager.enable = true;
 home.stateVersion = "24.11";
 #home.stateVersion = "24.11";
 home.username = "wtoorren";
 #home.username = "${config.username}";
 home.packages = with pkgs; [
    atuin
  ];

home.sessionVariables = {
    LANG= "en_US.UTF-8";
    LC_ALL= "en_US.UTF-8";
  };

#  home.file.".togglrcnew".source = "/tmp/toggl.txt";


  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
}
