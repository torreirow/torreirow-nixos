{ config, ... }:

# Quiqr (Hugo CMS) als AppImage via appimage-run. Ook 0.19.9 draait nog op
# Electron 9, dat geen Wayland kent: met de globale GDK_BACKEND=wayland
# (envs.nix) stopt hij met "cannot open display: :0". GDK_BACKEND=x11 laat hem
# via Xwayland draaien. Zelfde commando als de `quiqr`-alias in zsh.nix.

let
  appimage = "${config.home.homeDirectory}/data/progs/quiqr_0.19.9_linux_x86_64.AppImage";
in
{
  xdg.dataFile."icons/hicolor/512x512/apps/quiqr.png".source = ../../home/icons/quiqr.png;

  xdg.desktopEntries.quiqr = {
    name = "Quiqr";
    genericName = "Hugo CMS";
    comment = "Desktop CMS voor Hugo-sites";
    exec = "env GDK_BACKEND=x11 appimage-run ${appimage}";
    icon = "quiqr";
    terminal = false;
    type = "Application";
    categories = [ "Development" "WebDevelopment" ];
    settings = {
      StartupWMClass = "quiqr";
    };
  };
}
