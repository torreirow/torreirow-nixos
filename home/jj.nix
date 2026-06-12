{ pkgs, ... }: {

  home.packages = [
    pkgs.jjui
    pkgs.lazyjj
  ];

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Wouter Toorren";
        email = "wouter@technative.eu";
      };
      ui = {
        default-command = [ "log" "--no-pager" ];
      };
    };
  };

}
