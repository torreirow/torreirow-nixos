{ lib, pkgs, ... }:

{
  # GNOME Wayland user-level configuratie
  # System-level Mutter settings staan in hosts/lobos/gnome-wayland.nix

  # User-level Wayland environment variables (aanvullend op system-level)
  home.sessionVariables = {
    # XDG session type expliciteren (helpt met detectie)
    XDG_SESSION_TYPE = "wayland";

    # XDG current desktop voor applicatie compatibility
    XDG_CURRENT_DESKTOP = "GNOME";

    # Wayland display socket (normaal automatisch, maar expliciteren helpt)
    # WAYLAND_DISPLAY wordt automatisch gezet door compositor
  };

  # Extra Wayland-compatible packages voor user
  home.packages = with pkgs; [
    wl-clipboard        # Wayland clipboard utilities (wl-copy, wl-paste)
    wl-clipboard-x11    # X11 compatibility wrapper (xclip, xsel via Wayland)
    wtype               # xdotool alternative voor Wayland
  ];
}
