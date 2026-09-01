{ config, lib, pkgs, ... }:

# GNOME Desktop + Wayland configuratie voor GNOME 49+
# Bevat fixes voor Qt en Electron apps die geen venster tonen op Wayland

{
  # ===== GNOME Desktop Environment =====
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  # Stabiele session file voor Hyprland+UWSM: gebruikt /run/current-system/sw/bin/uwsm
  # (altijd symlink naar huidige versie) i.p.v. een nix store hash die na updates stale wordt.
  # tuigreet --remember-session slaat het Exec= commando op; met een stabiel pad werkt dit
  # ook na nixpkgs updates zonder handmatige tussenkomst.
  environment.etc."wayland-sessions/hyprland-uwsm-stable.desktop" = {
    mode = "0644";
    text = ''
      [Desktop Entry]
      Name=Hyprland (UWSM)
      Comment=An intelligent dynamic tiling Wayland compositor
      Exec=/run/current-system/sw/bin/uwsm start -e -D Hyprland hyprland.desktop
      TryExec=/run/current-system/sw/bin/uwsm
      DesktopNames=Hyprland
      Type=Application
    '';
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /etc/wayland-sessions:/run/current-system/sw/share/wayland-sessions --xsessions /run/current-system/sw/share/xsessions";
        user = "greeter";
      };
    };
  };
  services.gnome.gnome-settings-daemon.enable = true;
  services.gnome.gnome-keyring.enable = true;  # Voor VPN/WiFi secrets (NetworkManager)
  programs.xwayland.enable = true;

  # ===== Mutter/Wayland Settings =====
  # Experimental features voor betere Wayland/XWayland compatibility
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org/gnome/mutter]
    experimental-features=['scale-monitor-framebuffer']
    center-new-windows=true
  '';

  # ===== Wayland Environment Variables =====
  environment.sessionVariables = {
    # Force Qt apps to use native Wayland (fixes invisible windows op GNOME 49+)
    # Werkt voor: Strawberry, mscore/MuseScore, etc.
    QT_QPA_PLATFORM = "wayland";
  };

  environment.variables = {
    # Electron apps (Bitwarden, VSCode, Signal, etc.) Wayland fix voor GNOME 49+
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  # ===== XDG Portals =====
  # Voor Wayland screen sharing, file dialogs, etc.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };

  # ===== GNOME Packages =====
  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
  ]) ++ (with pkgs.gnome; [
    # gnome-characters
    # gnome-contacts
  ]);

  environment.systemPackages = with pkgs; [
    # GNOME Extensions
    gnomeExtensions.argos
    gnomeExtensions.appindicator
    gnomeExtensions.astra-monitor
    gnomeExtensions.caffeine
    gnomeExtensions.dock-from-dash
    gnomeExtensions.date-menu-formatter
    gnomeExtensions.gsconnect
    gnomeExtensions.night-light-slider-updated
    gnomeExtensions.unite
    gnomeExtensions.dash-to-panel
    gnomeExtensions.vitals
    gnomeExtensions.focus-changer
    gnomeExtensions.launcher
    gnomeExtensions.media-controls
    gnomeExtensions.search-light
    gnomeExtensions.useless-gaps
    gnomeExtensions.window-on-top
    # Clipboard: clipboard-history@alexsaveau.dev is handmatig geïnstalleerd en werkt goed

    # GNOME tools
    dconf
    gpaste        # Clipboard manager daemon (D-Bus activatie)
    wl-clipboard  # Wayland clipboard tools voor screenshot-to-file script
    networkmanagerapplet  # GUI voor VPN wachtwoord dialogen
    libsecret  # Voor secret-tool (GNOME Keyring beheer)
  ];

  programs.dconf.enable = true;

  # Installeer gnome-shell systemd user units in /etc/systemd/user/
  # Vereist voor GNOME 49+: org.gnome.Shell@wayland.service moet aanwezig zijn
  systemd.packages = [ pkgs.gnome-shell ];

  # Drop-in voor gnome-session@gnome.target: voeg org.gnome.Shell.target toe als Want
  # Zonder dit start gnome-session gnome-shell direct (oud gedrag) in plaats van via systemd.
  # Via systemd als unit: gnome-shell kan zichzelf vinden → XWayland initialiseert correct.
  # overrideStrategy="asDropin" is vereist voor template instances (@gnome).
  systemd.user.targets."gnome-session@gnome" = {
    overrideStrategy = "asDropin";
    unitConfig = {
      Wants = "org.gnome.Shell.target";
    };
  };

  # GPaste-daemon (X11-klembordbeheer) wordt hier BEWUST NIET als user-service gestart.
  # Onder Hyprland draait de daemon via XWayland en kaapt de X11 CLIPBOARD-selectie; XWayland
  # bridget die naar Wayland, waardoor kopiëren in Wayland-apps stukgaat (alacritty Ctrl+Shift+C,
  # tmux-yank/wl-copy plakken niets meer). Klembordbeheer loopt op deze host via cliphist
  # (zie home/hyprland/bindings.nix: CTRL+SUPER+C). Een eerdere poging om de daemon met
  # GDK_BACKEND=x11 tóch te laten draaien liet 'm wél starten, maar brak juist het klembord.
  # Onder een echte GNOME-sessie kan GPaste desgewenst via de gnome-shell-extensie/D-Bus
  # geactiveerd worden; daar is deze systemd-service niet voor nodig.
}
