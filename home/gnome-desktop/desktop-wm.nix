{ ... }:

{
  # GNOME Window Manager preferences
  dconf.settings = {
    "org/gnome/desktop/wm/preferences" = {
      # Window button layout: minimize, maximize, close aan de rechterkant
      button-layout = "appmenu:minimize,maximize,close";
    };

    # Disable default Alt+Space window menu (conflicts with search-light)
    "org/gnome/desktop/wm/keybindings" = {
      activate-window-menu = [];
    };

    # Search-light extension: Alt+Space for search
    "org/gnome/shell/extensions/search-light" = {
      shortcut-search = ["<Alt>space"];
    };
  };
}
