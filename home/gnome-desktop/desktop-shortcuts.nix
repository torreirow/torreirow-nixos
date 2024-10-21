{ ... }:

# Custom Gnome keyboard keys are listed here:
# https://discussion.fedoraproject.org/t/custom-keyboard-layout-in-gnome-wayland/68923
{


  dconf.settings = {

#    "org/gnome/desktop/wm/keybindings" = {
#      close                        = [ "<Super>q" ];
#      cycle-windows-backward       = [ "<Shift><Super>Escape" ];
#      maximize                     = [ "<Super>Up" ];
#      toggle-maximized             = [ "<Super>t" ];
#      minimize                     = [ "<Alt>F4" ];
#      move-to-workspace-1          = [];
#      move-to-workspace-2          = [];
#      move-to-workspace-3          = [];
#      move-to-workspace-4          = [];
#      show-desktop                 = [ "F12" ];
#      switch-input-source          = [];
#      switch-input-source-backward = [];
#      switch-to-workspace-1        = [];
#      switch-to-workspace-2        = [];
#      switch-to-workspace-3        = [];
#      switch-to-workspace-4        = [];
#      switch-to-workspace-last     = [];
#      toggle-fullscreen            = [ "<Super>f" ];
#      cycle-windows                = [ "<Super>Escape" ];
#    };
#
#    "org/gnome/shell/keybindings" = {
#      toggle-quick-settings        = [ "<Shift><Control>s" ];
#    };
#
#    "org/gnome/mutter/keybindings" = {
#      toggle-tiled-left = [ "<Primary><Shift>Left" ];
#      toggle-tiled-right = [ "<Primary><Shift>Right" ];
#    };
#
#    # FIX OVERLAP WITH SUPER ESCAPE CYCLE WINDOWS
#    "org/gnome/mutter/wayland/keybindings" = {
#      restore-shortcuts=[""];
#    };



    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
      #screensaver = [];
      #search = [ "<Super>/" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>Return";
      command = "env alacritty";
      name = "alacritty";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Ctrl><Shift><Alt>T";
      command = ''toggl start -o  "TN-General" "General. Tasks not further specified"'';
      name = "toggl general";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Shift><Super>asciicircum";
      command = "slack";
      name = "slack";
    };
  };
}
