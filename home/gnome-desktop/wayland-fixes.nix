{ lib, ... }:

{
  # GNOME 49+ Wayland window positioning fixes
  dconf.settings = {
    "org/gnome/mutter" = {
      # Experimental features voor betere window handling in GNOME 49+
      experimental-features = [ "scale-monitor-framebuffer" ];

      # Center new windows (helpt met positioning issues)
      center-new-windows = true;
    };
  };
}
