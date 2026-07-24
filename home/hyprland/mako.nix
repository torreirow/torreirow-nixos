{ ... }:

{
  services.mako = {
    enable = true;
    settings = {
      font             = "JetBrains Mono 12";
      background-color = "#1d2021";   # Gruvbox bg hard
      text-color       = "#d5c4a1";   # Gruvbox fg1
      border-color     = "#83a598";   # Gruvbox blue
      progress-color   = "#b8bb26";   # Gruvbox green
      border-size      = 2;
      border-radius    = 0;
      padding          = "10";
      margin           = "10";
      width            = 420;
      height           = 110;
      max-visible      = 5;
      sort             = "-time";
      group-by         = "app-name";
      anchor           = "top-right";
      layer            = "overlay";
      default-timeout  = 5000;
      markup           = true;
      actions          = true;
      format           = "<b>%s</b>\\n%b";
    };

    extraConfig = ''
      [urgency=high]
      border-color=#fb4934
      default-timeout=0
    '';
  };
}
