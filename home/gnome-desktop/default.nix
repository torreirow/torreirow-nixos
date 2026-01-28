{ lib, ... }:

{
  imports = [
#    ./desktop-generic.nix
#    ./desktop-input-sources.nix
    ./desktop-shortcuts.nix
#    ./wayland-fixes.nix  # Verwijderd: veroorzaakt problemen met wxWidgets apps (bambu-studio)
#    ./desktop-gpaste.nix
#    ./shell-generic.nix
#    ./shell-ext.nix
  ];
}
