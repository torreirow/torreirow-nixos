{ config, pkgs, lib, ... }:

let
  cfg = config.services.formrelay;

  formrelayPkg = pkgs.callPackage ../pkgs/formrelay { };

  formEntry = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Leesbare naam, gebruikt in email onderwerp";
      };
      to = lib.mkOption {
        type = lib.types.str;
        description = "Ontvanger emailadres";
      };
      allowedOrigins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Toegestane Origins (bijv. https://wereldvanbegrip.nl)";
      };
    };
  };

  configFile = pkgs.writeText "formrelay-config.json" (builtins.toJSON {
    port = cfg.port;
    fromAddress = cfg.fromAddress;
    forms = cfg.forms;
  });

in {
  options.services.formrelay = {
    enable = lib.mkEnableOption "formrelay form-to-email relay service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8094;
      description = "Luisterpoort op localhost";
    };

    fromAddress = lib.mkOption {
      type = lib.types.str;
      default = "forms@toorren.net";
      description = "Afzender emailadres voor uitgaande formuliermail";
    };

    forms = lib.mkOption {
      type = lib.types.attrsOf formEntry;
      default = {};
      description = "Map van token string naar formulier configuratie";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.hcaptcha-secret = {
      file = ../secrets/hcaptcha-secret.age;
      path = "/run/secrets/hcaptcha-secret";
      mode = "0444"; # World-readable nodig voor DynamicUser systemd service
    };

    systemd.services.formrelay = {
      description = "formrelay form-to-email relay";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "postfix.service" ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        SupplementaryGroups = [ "keys" ];
        ExecStart = "${formrelayPkg}/bin/formrelay --config=${configFile} --hcaptcha-secret-file=/run/secrets/hcaptcha-secret";
        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    services.nginx.virtualHosts."forms.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/submit" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        extraConfig = ''
          limit_req zone=vwlogin burst=10 nodelay;
          proxy_read_timeout 10s;
        '';
      };

      locations."/" = {
        return = "404";
      };
    };
  };
}
