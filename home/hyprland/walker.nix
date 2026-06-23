{ walker-input, pkgs, ... }:

{
  imports = [ walker-input.homeManagerModules.default ];

  programs.elephant = {
    enable = true;
    debug = true;
    installService = false;
    providers = [
      "desktopapplications"
      "calc"
      "runner"
      "clipboard"
      "symbols"
      "websearch"
      "menus"
      "providerlist"
    ];
    settings = {
      providers.desktopapplications = {
        launch_prefix = "uwsm app -- ";
        min_score = 60;
      };
    };
  };

  programs.walker = {
    enable = true;
    runAsService = false;
  };
}
