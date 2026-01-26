{ lib, ... }:

{
  imports = [
#    ./desktop-generic.nix
#    ./desktop-input-sources.nix
    ./desktop-shortcuts.nix
    ./wayland-fixes.nix
#    ./desktop-gpaste.nix
#    ./shell-generic.nix
#    ./shell-ext.nix
  ];
}
