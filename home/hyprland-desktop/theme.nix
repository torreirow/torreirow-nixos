{ config, pkgs, ... }:

{
  gtk = {
    enable = true;

    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    font = {
      name = "Sans";
      size = 11;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-cursor-theme-name = "Bibata-Modern-Classic";
      gtk-cursor-theme-size = 24;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-cursor-theme-name = "Bibata-Modern-Classic";
      gtk-cursor-theme-size = 24;
    };
  };

  # Qt theming to match GTK
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # Cursor theme for Wayland
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
