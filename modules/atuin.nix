{
  config,
  lib,
  ...
}:

# Atuin shell-history-syncserver, met nginx-vhost. De server zelf komt uit de
# nixpkgs-module `services.atuin`; deze module voegt alleen de vhost-opties toe
# en zet de vhost op `atuin.<domein>` achter het wildcard-cert.
#
# Draait de server op loopback (default) met een lokale PostgreSQL-database en
# rol `atuin` (database.createLocally). Geen registratie openbaar: nieuwe
# accounts aanmaken doe je bewust met openRegistration = true, daarna weer uit.
#
# Client (lokaal):
#   atuin register --server https://atuin.toorren.net
#   atuin login --server https://atuin.toorren.net
#   atuin sync

let
  cfg = config.services.atuin;
in
{
  options.services.atuin.nginx = {
    enable = lib.mkEnableOption "nginx-vhost voor de Atuin-server";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "atuin.toorren.net";
      description = "Publieke hostnaam voor de Atuin-server.";
    };

    acmeHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "toorren.net";
      description = ''
        Naam van het bestaande security.acme.certs.<naam> (wildcard-cert).
        Op null zetten laat de vhost zelf een certificaat aanvragen.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.nginx.enable) {
    services.nginx.virtualHosts.${cfg.nginx.domain} =
      (if cfg.nginx.acmeHost != null then { useACMEHost = cfg.nginx.acmeHost; } else { enableACME = true; })
      // {
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://${cfg.host}:${toString cfg.port}";
          # Atuin-sync kan grotere history-batches posten.
          extraConfig = ''
            client_max_body_size 25M;
          '';
        };
      };
  };
}
