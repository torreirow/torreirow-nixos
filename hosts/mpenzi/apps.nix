# Apps voor mpenzi. Wat Maaike zelf wil installeren gaat via Discover + Flathub.
{ config, lib, pkgs, ... }:

let
  canvaIcon = pkgs.runCommand "canva-icon" { } ''
    install -Dm444 ${./canva.svg} $out/share/icons/hicolor/scalable/apps/canva.svg
  '';

  # Webapp als los venster via Chrome, met eigen naam en icoon in het startmenu.
  webapp = { name, desktopName, comment, url, icon, categories }: pkgs.makeDesktopItem {
    inherit name desktopName comment icon categories;
    exec = "${lib.getExe pkgs.google-chrome} --app=${url}";
  };

  canva = webapp {
    name = "canva";
    desktopName = "Canva";
    comment = "Ontwerpen maken met Canva";
    url = "https://www.canva.com";
    icon = "canva";
    categories = [ "Graphics" ];
  };

  # jitsi-meet-electron hangt in nixpkgs 26.05 aan een EOL-Electron (als insecure gemarkeerd);
  # Jitsi werkt in Chrome net zo goed, dus een webapp in plaats van dat pakket.
  jitsi = webapp {
    name = "jitsi-meet";
    desktopName = "Jitsi Meet";
    comment = "Videobellen met Jitsi";
    url = "https://meet.jit.si";
    icon = "camera-web";
    categories = [ "Network" "VideoConference" ];
  };

  # Nextcloud start op de achtergrond mee bij inloggen (alleen tray-icoon).
  nextcloudAutostart = pkgs.makeDesktopItem {
    name = "nextcloud-autostart";
    desktopName = "Nextcloud";
    exec = "${lib.getExe' pkgs.nextcloud-client "nextcloud"} --background";
    icon = "Nextcloud";
    noDisplay = true;
  };
in
{
  programs.firefox.enable = true;
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };

  environment.systemPackages = with pkgs; [
    google-chrome
    onlyoffice-desktopeditors
    nextcloud-client
    thunderbird
    zoom-us
    bitwarden-desktop
    kdePackages.discover
    canva
    jitsi
    canvaIcon
  ];

  # OnlyOffice zonder Microsoft-fonts verschuift Word-documenten.
  fonts.packages = with pkgs; [ corefonts vista-fonts ];

  environment.etc."xdg/autostart/nextcloud.desktop".source =
    "${nextcloudAutostart}/share/applications/nextcloud-autostart.desktop";

  # Discover installeert apps uit Flathub; de remote voegen we eenmalig systeembreed toe.
  services.flatpak.enable = true;
  systemd.services.flatpak-flathub = {
    description = "Flathub-remote toevoegen";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Zonder netwerk bij boot later opnieuw; faalt niet hard op een laptop zonder wifi.
      Restart = "on-failure";
      RestartSec = "5min";
    };
  };
}
