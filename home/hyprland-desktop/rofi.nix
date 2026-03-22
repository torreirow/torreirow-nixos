{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;

    theme = "Arc-Dark";

    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      display-drun = " Apps";
      display-run = " Run";
      display-window = " Windows";
      drun-display-format = "{name}";
      window-format = "{w} · {c} · {t}";
      font = "JetBrainsMono Nerd Font 11";

      # Window position
      location = 0;
      width = 35;
      lines = 10;
      columns = 1;

      # Behavior
      case-sensitive = false;
      cycle = true;
      sidebar-mode = true;
      hover-select = false;

      # Matching
      matching = "fuzzy";
      sort = true;
      sorting-method = "fzf";
    };
  };
}
