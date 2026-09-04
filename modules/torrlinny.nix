{ config, lib, pkgs, ... }:

# Torrlinny notities-web — nu een DUNNE WRAPPER rond de gedeelde, herbruikbare
# `services.linny-web` module (flake github:torreirow/linny-web-theme,
# geïmporteerd via de malandro modules-lijst in flake.nix). Zie epic nixos-dhh8
# (de generieke module) + feature nixos-9596 (deze migratie).
#
# Deze wrapper voegt alleen het malandro-specifieke toe:
#  - de read-only SSH deploy-key voor de privé-repo via agenix;
#  - de bestaande Authelia nginx-vhost op linny.toorren.net (NIET de dunne
#    nginx-helper van de module — die kent Authelia niet);
#  - domain/acmeHost blijven torrlinny-specifiek.
#
# De clone/build/atomic-swap/keep-last-good/timer/change-detectie + het
# permissie-model zitten nu allemaal in de gedeelde module.

with lib;

let
  cfg = config.services.torrlinny;
  autheliaHelpers = import ./authelia-nginx.nix { inherit lib; };
in {
  options.services.torrlinny = {
    enable = mkEnableOption "Torrlinny notities-web (via de gedeelde linny-web module, achter Authelia)";

    domain = mkOption {
      type = types.str;
      default = "linny.toorren.net";
      description = "Domein waarop de site geserveerd wordt (achter Authelia).";
    };

    acmeHost = mkOption {
      type = types.str;
      default = "toorren.net";
      description = "ACME-host voor het (wildcard) TLS-certificaat.";
    };
  };

  config = mkIf cfg.enable {
    ###### Deploy key (read-only) voor de privé-repo ######
    age.secrets.torrlinny-deploy-key = {
      file = ../secrets/torrlinny-deploy-key.age;
      path = "/run/agenix/torrlinny-deploy-key";
      owner = "torrlinny";
      mode = "0400";
    };

    ###### Gedeelde linny-web module, gericht op torrlinny's repo + paden ######
    services.linny-web = {
      enable = true;
      gitRepo = "git@github.com:torreirow/torrlinny.git";
      gitSshKeyFile = config.age.secrets.torrlinny-deploy-key.path;
      baseURL = "https://${cfg.domain}/";
      # Behoud de bestaande user + werkmap zodat de live-build ononderbroken blijft.
      user = "torrlinny";
      stateDir = "/var/lib/torrlinny";
      webRoot = "/var/lib/torrlinny/live";
    };

    # De deploy-key staat in /run/keys (root:keys 0750); de build-user moet in de
    # 'keys'-groep zitten om 'm te lezen (zelfde patroon als formrelay). De gedeelde
    # module zet dit niet, dus we vullen het hier aan op de build-service.
    systemd.services.linny-web-build.serviceConfig.SupplementaryGroups = [ "keys" ];

    ###### Nginx: serveer de live static-map achter Authelia ######
    # Bewust NIET de dunne nginx-helper van de module: die kent Authelia niet.
    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      useACMEHost = cfg.acmeHost;
      root = config.services.linny-web.webRoot;

      locations."/authelia" = autheliaHelpers.autheliaVerifyLocation;

      locations."/" = {
        tryFiles = "$uri $uri/ =404";
        extraConfig = autheliaHelpers.autheliaAuthConfig;
      };
    };
  };
}
