{ ... }:

{
  services.mako = {
    enable = true;

    settings = {
      background-color = "#1e1e2e";
      text-color       = "#cdd6f4";
      border-color     = "#cba6f7";
      border-size      = 2;
      border-radius    = 8;
      padding          = "10,15";
      margin           = "10";
      width            = 350;
      height           = 110;
      max-visible      = 5;
      font             = "JetBrains Mono 11";
      default-timeout  = 5000;
    };

    extraConfig = ''
      [urgency=high]
      border-color=#f38ba8
      default-timeout=0
    '';
  };
}
