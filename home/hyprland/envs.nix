{ config, ... }:

{
  home.sessionVariables = {
    BROWSER = "firefox";
    XCURSOR_SIZE = "24";
    XCURSOR_THEME = "Adwaita";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    OZONE_PLATFORM = "wayland";
    ADW_DISABLE_PORTAL = "1";
  };

  systemd.user.sessionVariables = config.home.sessionVariables;

  wayland.windowManager.hyprland.settings = {
    env = [
      "XCURSOR_SIZE,24"
      "XCURSOR_THEME,Adwaita"
      "GDK_BACKEND,wayland"
      "QT_QPA_PLATFORM,wayland"
      "SDL_VIDEODRIVER,wayland"
      "MOZ_ENABLE_WAYLAND,1"
      "ELECTRON_OZONE_PLATFORM_HINT,wayland"
      "OZONE_PLATFORM,wayland"
    ];

    xwayland.force_zero_scaling = true;

    ecosystem.no_update_news = true;
  };
}
