# Shell-hulpmiddelen die lobos, malandro en het wtoorren-admin-profiel delen.
{ unstable, ... }:

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
    package = unstable.atuin;
    enableZshIntegration = true;
    flags = [
      "--disable-up-arrow"
    ];
    daemon = {
      enable = true;
    };
    settings = {
      auto_sync = true;
      daemon.sync_frequency = 300;  # seconden — sync gebeurt nu via de daemon
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
}
