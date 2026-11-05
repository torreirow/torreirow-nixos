{ config, pkgs, lib, unstable, ... }:

# Immich op https://photos.toorren.net: fotobackup van de telefoon en foto-bron (API-sleutel)
# voor de reisapps MarkMySteps en OwnSteps. Zie docs/immich.md.
#
# - Originelen op het eigen JuiceFS-volume (modules/juicefs-immich.nix), thumbnails en
#   omgezette video lokaal: die zijn opnieuw te maken en worden vaak gelezen.
# - Immich 3.x uit unstable: 26.05 levert alleen 2.7.5 (end-of-life, CVE's).
# - Machine learning niet hier (de Celeron J3455 heeft geen AVX) maar op lobos, via Nebula
#   (modules/immich-ml.nix). Video omzetten via VAAPI op de HD 500, met een kleine patch
#   (modules/immich-vaapi-patch.nix).
# - Login via Authelia-OIDC (client `immich` in modules/authelia.nix). GEEN forward-auth:
#   de Immich-app, API-sleutels en deellinks moeten zonder werken (zoals OwnSteps).

let
  port = 2283;
  domain = "photos.toorren.net";
  mountPoint = "/data/juicefs-immich";
  mediaLocation = "${mountPoint}/immich";
  localDir = "/data/external/immich";
  # Deze submappen van mediaLocation komen van de lokale schijf.
  localSubdirs = [ "thumbs" "encoded-video" ];
  renderNode = "/dev/dri/renderD128";
  # format=nv12 vóór hwupload, anders faalt VAAPI bij bronnen ≤ 720p (zie het bestand).
  immichPackage = pkgs.callPackage ./immich-vaapi-patch.nix { immich = unstable.immich; };
in
{
  age.secrets.immich-oidc = {
    file = ../secrets/immich-oidc.age;
    mode = "0400"; # de module leest hem als root via LoadCredential
  };

  services.immich = {
    enable = true;
    # 3.x uit unstable; de module komt ook uit unstable (flake.nix, malandro-modules).
    package = immichPackage;
    host = "127.0.0.1";
    inherit port mediaLocation;
    machine-learning.enable = false;
    # Alleen de render-node van de HD 500 (VAAPI); verder blijft /dev afgeschermd.
    accelerationDevices = [ renderNode ];
    # Een settings-bestand maakt de instellingen in de web-UI alleen-lezen: wijzigen gaat hier.
    settings = {
      server.externalDomain = "https://${domain}";
      newVersionCheck.enabled = false;
      # ML draait op lobos (modules/immich-ml.nix). Staat lobos uit, dan wordt de URL na de
      # availability-check overgeslagen en mislukken ML-taken; later "Ontbrekende" draaien.
      machineLearning = {
        enabled = true;
        urls = [ "http://10.77.0.2:3003" ];
      };
      # VAAPI op de HD 500: H.264-encode en HEVC-decode (ook 10-bit), 3-4x sneller dan de CPU.
      # Kan de GPU de bron niet decoderen (mpeg4, H.264 Baseline), dan valt Immich zelf terug
      # op software-decode + VAAPI-encode, en daarna op de CPU. Zie docs/immich.md.
      ffmpeg = {
        accel = "vaapi";
        accelDecode = true;
      };
      passwordLogin.enabled = true; # admin-reserve naast OIDC
      oauth = {
        enabled = true;
        issuerUrl = "https://auth.toorren.net";
        clientId = "immich";
        clientSecret._secret = config.age.secrets.immich-oidc.path;
        tokenEndpointAuthMethod = "client_secret_post";
        scope = "openid email profile";
        signingAlgorithm = "RS256";
        buttonText = "Inloggen met Authelia";
        autoRegister = true;
        autoLaunch = false;
        # Authelia accepteert app.immich:///oauth-callback; anders: true +
        # mobileRedirectUri = "https://${domain}/api/oauth/mobile-redirect".
        mobileOverrideEnabled = false;
        mobileRedirectUri = "";
      };
    };
  };

  # VA-API-driver voor de HD 500 (Apollo Lake): iHD uit intel-media-driver.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };

  systemd.tmpfiles.rules = [ "d ${localDir} 0700 immich immich -" ]
    ++ map (d: "d ${localDir}/${d} 0700 immich immich -") localSubdirs;

  # Immich draait alleen als de JuiceFS-mount er is: valt die weg, dan stopt Immich mee
  # (BindsTo) en schrijft hij niet in de lege onderliggende map.
  systemd.services.immich-server = {
    after = [ "juicefs-immich.service" ];
    bindsTo = [ "juicefs-immich.service" ];
    environment.LIBVA_DRIVER_NAME = "iHD";
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.util-linux}/bin/mountpoint -q ${mountPoint}"
      ];
      BindPaths = map (d: "${localDir}/${d}:${mediaLocation}/${d}") localSubdirs;
    };
  };
  # De bind-doelen moeten in het volume bestaan.
  systemd.services.juicefs-immich.serviceConfig.ExecStartPost = lib.mkAfter (
    map (d: "${pkgs.coreutils}/bin/install -d -m 0700 -o immich -g immich ${mediaLocation}/${d}")
      localSubdirs
  );

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "toorren.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 50000M;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        send_timeout 600s;
      '';
    };
  };
}
