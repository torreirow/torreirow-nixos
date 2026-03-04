{ config, lib, pkgs, hyprland-pkg, ... }:

let
  # Wrapper that preserves .override attribute
  # Uses overrideAttrs instead of symlinkJoin to keep all derivation attributes
  hyprland-fixed = hyprland-pkg.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      # Add gcc-15 libraries to RPATH to fix GLIBCXX_3.4.34 error
      for binary in $out/bin/Hyprland $out/bin/.Hyprland-wrapped; do
        if [ -f "$binary" ] && [ ! -L "$binary" ]; then
          ${pkgs.patchelf}/bin/patchelf \
            --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib:$(${pkgs.patchelf}/bin/patchelf --print-rpath $binary)" \
            $binary || true
        fi
      done
    '';
  });
in
{
  # Enable Hyprland window manager
  programs.hyprland = {
    enable = true;
    package = hyprland-fixed;  # Use patched package with gcc-15 in RPATH
    xwayland.enable = true;  # Enable XWayland for legacy apps
  };

  # XDG Portals for both GNOME and Hyprland
  # Note: xdg-desktop-portal-hyprland is provided by the Hyprland flake module
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome      # For GNOME
      xdg-desktop-portal-gtk        # For GTK file pickers
    ];
  };

  # Essential Hyprland system packages
  environment.systemPackages = with pkgs; [
    # Status bar and launcher
    waybar
    wofi

    # Notification daemon
    mako

    # Native Hyprland tools
    grimblast         # Screenshot helper
    hyprpaper         # Wallpaper daemon
    hyprlock          # Screen locker
    hypridle          # Idle management

    # Clipboard
    wl-clipboard

    # Screen recording
    wf-recorder

    # Network manager applet (for waybar tray)
    networkmanagerapplet

    # Volume control (for waybar)
    pavucontrol

    # Brightness control
    brightnessctl

    # Polkit agent (for authentication dialogs)
    polkit_gnome

    # Logout menu
    wlogout
  ];

  # Security: enable polkit
  security.polkit.enable = true;

  # GDM will automatically detect both GNOME and Hyprland sessions
  # No additional configuration needed - both will appear in session selector
}
