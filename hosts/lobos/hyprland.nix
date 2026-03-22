{ config, pkgs, unstable, ... }:

let
  # Wrapper script for Hyprland with gcc-15 libstdc++ workaround
  hyprland-wrapper = pkgs.writeShellScriptBin "hyprland-wrapped" ''
    export LD_LIBRARY_PATH="/nix/store/w4x4zgjnr2m0v7kz96vwz1myj93ngy7c-gcc-15.2.0-lib/lib:$LD_LIBRARY_PATH"
    exec ${unstable.hyprland}/bin/Hyprland "$@"
  '';
in
{
  # Enable X11 for XWayland support
  services.xserver.enable = true;

  # Enable Hyprland with UWSM support (from unstable to fix gcc-15 issue)
  programs.hyprland = {
    enable = true;
    package = unstable.hyprland;
    portalPackage = unstable.xdg-desktop-portal-hyprland;
    withUWSM = true;
    xwayland.enable = true;
  };

  # greetd display manager met tuigreet (TUI login)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd ${hyprland-wrapper}/bin/hyprland-wrapped";
        user = "greeter";
      };
    };
  };

  # XDG Portal - gtk for file picker, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.hyprland.default = ["hyprland" "gtk"];
  };

  # Core Hyprland system packages
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wl-clipboard
    wl-clip-persist

    # Screenshot tools
    grim
    slurp

    # Brightness control
    brightnessctl

    # Media control
    playerctl

    # Polkit agent for authentication
    polkit_gnome
  ];

  # Environment variables for Wayland apps
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland";  # Qt apps native Wayland
  };

  environment.variables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";  # Electron apps native Wayland
  };

  # Enable polkit for authentication dialogs
  security.polkit.enable = true;

  # GNOME Keyring for credential storage (works with Hyprland)
  services.gnome.gnome-keyring.enable = true;
}
