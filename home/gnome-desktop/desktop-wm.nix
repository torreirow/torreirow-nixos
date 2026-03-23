{ ... }:

{
  # GNOME Window Manager preferences
  dconf.settings = {
    "org/gnome/desktop/wm/preferences" = {
      # Window button layout: minimize, maximize, close aan de rechterkant
      button-layout = "appmenu:minimize,maximize,close";
    };
  };
}
