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

  # SMPlayer is de standaard-videospeler; VLC staat ernaast. Beide gebruiken de ffmpeg van
  # nixpkgs (AV1/dav1d, HEVC, VP9, Opus); hardware-decodering via VA-API (mesa radeonsi).
  videoTypes = [
    "video/mp4" "video/x-matroska" "video/webm" "video/quicktime" "video/x-msvideo"
    "video/mpeg" "video/x-flv" "video/x-ms-wmv" "video/3gpp" "video/ogg" "video/mp2t"
    "video/x-m4v" "video/av1"
  ];

  smplayerIni = pkgs.writeText "smplayer.ini" ''
    [performance]
    hwdec=auto
  '';
in
{
  programs.firefox.enable = true;
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  } // lib.genAttrs videoTypes (_: "smplayer.desktop");

  environment.systemPackages = with pkgs; [
    google-chrome
    onlyoffice-desktopeditors
    nextcloud-client
    thunderbird
    zoom-us
    bitwarden-desktop
    spotify
    signal-desktop
    audacity
    zapzap # WhatsApp (Qt-wrapper om WhatsApp Web; geen officiële Linux-app)
    smplayer
    mpv # backend van SMPlayer; het smplayer-pakket brengt hem niet zelf mee
    vlc
    kdePackages.discover
    canva
    jitsi
    canvaIcon
  ];

  # SMPlayer-startconfig voor maaike: hardware-decodering aan (VA-API, radeonsi; de Ryzen 4700U
  # decodeert H.264/HEVC/VP9 in hardware, AV1 gaat via dav1d). tmpfiles `C` kopieert alleen als
  # het bestand nog niet bestaat, dus wat Maaike daarna in SMPlayer kiest blijft staan. Wordt
  # later onderdeel van herstel-app (epic nixos-kzxu).
  systemd.tmpfiles.rules = [
    "d /home/maaike/.config 0700 maaike users -"
    "d /home/maaike/.config/smplayer 0755 maaike users -"
    "C /home/maaike/.config/smplayer/smplayer.ini - - - - ${smplayerIni}"
    "z /home/maaike/.config/smplayer/smplayer.ini 0644 maaike users -"
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
