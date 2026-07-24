{ pkgs, ... }:

{
  home.packages = [ pkgs.cliphist ];

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "Inter:size=12";
        width = 35;
        lines = 10;
        horizontal-pad = 20;
        vertical-pad = 12;
        inner-pad = 8;
        line-height = 24;
      };
      colors = {
        background = "16161eff";
        text = "c0caf5ff";
        match = "7aa2f7ff";
        selection = "292e42ff";
        "selection-text" = "c0caf5ff";
        "selection-match" = "7aa2f7ff";
        border = "7aa2f7ff";
      };
      border = {
        width = 1;
        radius = 12;
      };
    };
  };
}
