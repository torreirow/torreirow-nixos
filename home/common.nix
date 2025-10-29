{config,pkgs,services,lib, ...}: 

{

programs.direnv = {
  enable = true;
  enableZshIntegration = true;
}; 

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
      dialect = "uk";
      filter_mode = "host";
      common_prefix = [ 
        "ls"
        "cd"
        "z"
        "grep"
        "vi"
      ];
      common_subcommands = [ 
        "aws-switch"
        "bmc"
        "race"
      ];
      secrets_filter = true;
      history_filter = [ 
        "^export.*KEY"
        "^export.*TOKEN"
      ]; 
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
 home.stateVersion = "25.05";
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
