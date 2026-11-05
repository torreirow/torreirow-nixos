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
in
{
  # Extensies afgedwongen (force_installed: Maaike kan ze niet per ongeluk weghalen). Zelfde
  # AMO-route als hosts/lobos/programs.nix.
  programs.firefox = {
    enable = true;
    policies.ExtensionSettings =
      let
        ext = shortId: uuid: {
          name = uuid;
          value = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${shortId}/latest.xpi";
            installation_mode = "force_installed";
          };
        };
      in builtins.listToAttrs [
        (ext "bitwarden-password-manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
        (ext "ublock-origin"              "uBlock0@raymondhill.net")
      ];
  };

  # Policies voor Google Chrome (leest /etc/opt/chrome/policies): ExtensionInstallForcelist.
  # In Chrome uBlock Origin Lite, de MV2-versie werkt daar niet meer.
  programs.chromium = {
    enable = true;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
    ];
  };

  # Thunderbird met offline-kopie van de mail; het Gmail-account (OAuth) is handwerk.
  programs.thunderbird = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      Preferences = {
        "mail.server.default.offline_download" = { Value = true; Status = "default"; };
        "mail.server.default.autosync_offline_stores" = { Value = true; Status = "default"; };
      };
    };
  };
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  } // lib.genAttrs videoTypes (_: "smplayer.desktop");

  environment.systemPackages = with pkgs; [
    google-chrome
    onlyoffice-desktopeditors
    nextcloud-client
    zoom-us
    bitwarden-desktop
    spotify
    signal-desktop
    audacity
    zapzap # WhatsApp (Qt-wrapper om WhatsApp Web; geen officiële Linux-app)
    smplayer
    mpv # backend van SMPlayer; het smplayer-pakket brengt hem niet zelf mee
    vlc
    alacritty
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
