{ config, pkgs, ... }:

# OwnSteps (https://github.com/RainerZufall00/ownsteps): self-hosted reisblog als
# Polarsteps-vervanger, op reis.toorren.net. Proefopzet; zie docs/ownsteps.md.
#
# Bewust GEEN Authelia ervoor: de thuisblijvers openen geheime deellinks zonder account,
# en de Android-app praat met /api/v1 via een bearer-token. OwnSteps heeft een eigen login.
{
  # ADMIN_EMAIL, ADMIN_PASSWORD en ADMIN_NAME: maakt het eerste account aan bij de allereerste
  # start, zodat de setup-pagina niet open op internet staat tot iemand hem claimt.
  age.secrets.ownsteps-env = {
    file = ../secrets/ownsteps-env.age;
    path = "/run/agenix/ownsteps-env";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /data/external/ownsteps 0755 root root - -"
  ];

  virtualisation.oci-containers.containers.ownsteps = {
    # Vastgepind; upgraden = CHANGELOG lezen (een nieuwe major vraagt handwerk) en tag ophogen.
    image = "ghcr.io/rainerzufall00/ownsteps:0.6.0";
    autoStart = true;

    # Loopback: Docker-poorten omzeilen de NixOS-firewall. In de container altijd 2555.
    ports = [
      "127.0.0.1:8089:2555"
    ];
    # Bevat ownsteps.db (SQLite), de uploads en data/.secret (APP_SECRET, zelf gegenereerd).
    volumes = [
      "/data/external/ownsteps:/data"
    ];
    environment = {
      TZ = "Europe/Amsterdam";
      SITE_NAME = "Reis";
      PUBLIC_URL = "https://reis.toorren.net";
      # Alleen nginx zit ervoor.
      TRUSTED_PROXIES = "1";
      # Zonder MapTiler-key: OpenFreeMap + Nominatim/Photon.
      MAP_STYLE = "liberty";
    };
    environmentFiles = [ config.age.secrets.ownsteps-env.path ];
  };

  services.nginx.virtualHosts."reis.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8089";
      proxyWebsockets = true;
      extraConfig = ''
        # Video's tot 400 MB per stuk.
        client_max_body_size 500M;
        client_body_timeout 600s;
        proxy_request_buffering off;
      '';
    };
  };
}
