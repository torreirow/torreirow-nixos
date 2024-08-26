{config, lib, pkgs,  agenix, ... }:

{
  environment.systemPackages = with pkgs; [
    gnomeExtensions.argos
    gnomeExtensions.appindicator
    gnomeExtensions.astra-monitor
    gnomeExtensions.caffeine
    gnomeExtensions.dock-from-dash
    gnomeExtensions.dash-to-dock
    gnomeExtensions.date-menu-formatter
    gnomeExtensions.gsconnect
    gnomeExtensions.night-light-slider-updated
    gnomeExtensions.power-profile-switcher
    gnome.gpaste
    gnomeExtensions.unite
  ];
} 
