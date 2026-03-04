{ config, lib, pkgs, ... }:

# Custom wrappers voor apps die niet goed werken met Wayland fallbacks
# Deze apps hebben expliciete platform hints nodig of speciale configuratie

{
  # Wrapper scripts voor problematische apps
  # Deze forceren XWayland mode voor apps die niet goed werken met Wayland
  environment.systemPackages = with pkgs; [
    # OnlyOffice - Chromium/CEF app in bubblewrap sandbox
    # Heeft moeite met Wayland platform detectie
    (writeShellScriptBin "onlyoffice-x11" ''
      export GDK_BACKEND=x11
      export QT_QPA_PLATFORM=xcb
      export WAYLAND_DISPLAY=""
      exec ${onlyoffice-desktopeditors}/bin/onlyoffice-desktopeditors "$@"
    '')

    # SubtitleEdit - Mono/.NET app
    # Mono heeft geen goede Wayland ondersteuning
    (writeShellScriptBin "subtitleedit-x11" ''
      export GDK_BACKEND=x11
      export QT_QPA_PLATFORM=xcb
      export WAYLAND_DISPLAY=""
      exec ${subtitleedit}/bin/subtitleedit "$@"
    '')
  ];
}
