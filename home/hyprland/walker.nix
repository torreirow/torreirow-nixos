{ walker-input, pkgs, ... }:

{
  imports = [ walker-input.homeManagerModules.default ];

  programs.elephant = {
    enable = true;
    debug = false;
    installService = true;
    providers = [
      "desktopapplications"
      "calc"
      "runner"
      "clipboard"
      "symbols"
      "websearch"
      "menus"
      "providerlist"
      "windows"
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
