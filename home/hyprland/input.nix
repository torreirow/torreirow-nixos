{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    input = lib.mkDefault {
      kb_layout = "us";
      kb_variant = "intl";
      follow_mouse = 1;
      sensitivity = 0;
      touchpad = {
        natural_scroll = true;
        scroll_factor = 0.5;
      };
    };
  };
}
