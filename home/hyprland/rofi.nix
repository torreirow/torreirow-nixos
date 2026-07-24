{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
  };

  # Catppuccin Mocha theme als .rasi bestand
  xdg.configFile."rofi/catppuccin-mocha.rasi".text = ''
    * {
      bg0:  #1e1e2eF2;
      bg1:  #313244FF;
      bg2:  #585b70FF;
      fg0:  #cdd6f4FF;
      acc:  #cba6f7FF;
      red:  #f38ba8FF;

      background-color: transparent;
      text-color:       @fg0;
      border-color:     @acc;
    }

    window {
      width:            600px;
      border:           2px;
      border-radius:    8px;
      background-color: @bg0;
      padding:          8px;
    }

    mainbox {
      background-color: transparent;
      children:         [ inputbar, listview ];
      spacing:          8px;
    }

    inputbar {
      background-color: @bg1;
      border-radius:    6px;
      padding:          8px;
      children:         [ prompt, entry ];
    }

    prompt {
      enabled:          true;
      padding:          0px 6px 0px 0px;
      background-color: transparent;
      text-color:       @acc;
    }

    entry {
      background-color: transparent;
      text-color:       @fg0;
      placeholder-color: @bg2;
      placeholder:      "Zoeken...";
    }

    listview {
      background-color: transparent;
      lines:            8;
      columns:          1;
      spacing:          4px;
    }

    element {
      background-color: transparent;
      border-radius:    4px;
      padding:          6px 10px;
    }

    element selected {
      background-color: @bg1;
      text-color:       @acc;
    }

    element-icon {
      size:             1.2em;
      padding:          0px 8px 0px 0px;
    }

    element-text {
      background-color: transparent;
      text-color:       inherit;
    }
  '';

  xdg.configFile."rofi/config.rasi".text = ''
    configuration {
      modi:        "drun,run";
      show-icons:  true;
      drun-display-format: "{name}";
    }

    @theme "catppuccin-mocha"
  '';
}
