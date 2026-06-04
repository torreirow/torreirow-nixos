{ unstable, ... }: {
    programs.opencode = {
      enable = true;
      package = unstable.opencode;
      agents = { };
      commands = { };
      settings = {
        autoshare = false;
        autoupdate = true;
        plugin = [ "@tarquinen/opencode-dcp@latest" ];
        provider = {
          anthropic = {
            options = {
              baseURL = "https://api.anthropic.com/v1";
            };
          };
          amazon-bedrock = {
            options = {
              region = "eu-central-1";
              profile = "TEC-playground-student1";
            };
          };
        };
      };
      tui = {
        theme = "opencode";
      };
      themes = { };
    };
}
