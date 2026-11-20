{ config, lib, pkgs, ... }:

let
  cfg = config.services.vuln-radar;

  extraFromFile =
    if cfg.extraAssetsFile != null then builtins.fromJSON (builtins.readFile cfg.extraAssetsFile) else { };

  extraAssets = extraFromFile // cfg.extraAssets;

  duplicateHosts = lib.intersectLists (builtins.attrNames cfg.assets) (builtins.attrNames extraAssets);

  mergedAssets = cfg.assets // extraAssets;

  hostSources = host: [ (builtins.attrNames (host.dpkg or { })) (builtins.attrNames (host.nix or { })) (builtins.attrNames (host.upstream or { })) ];

  duplicatePackages = host:
    let
      sources = hostSources host;
    in
    lib.intersectLists (builtins.elemAt sources 0) (builtins.elemAt sources 1)
    ++ lib.intersectLists (builtins.elemAt sources 0) (builtins.elemAt sources 2)
    ++ lib.intersectLists (builtins.elemAt sources 1) (builtins.elemAt sources 2);

  allVersions = host:
    builtins.attrValues (host.dpkg or { }) ++ builtins.attrValues (host.nix or { }) ++ builtins.attrValues (host.upstream or { });

  hostIsValid = name: host:
    name != ""
    && (host.release or "") != ""
    && duplicatePackages host == [ ]
    && lib.all (version: version != "") (allVersions host);

  invalidHosts = lib.filter (name: !(hostIsValid name mergedAssets.${name})) (builtins.attrNames mergedAssets);

  assetsJson = builtins.toJSON mergedAssets;
in
{
  options.services.vuln-radar = {
    enable = lib.mkEnableOption "version-aware CVE dashboard";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9101;
      description = "Local port for the vuln-radar collector.";
    };

    assets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          os = lib.mkOption {
            type = lib.types.enum [ "debian" "ubuntu" "nixos" "upstream" ];
            description = "OS/ecosystem family of the system.";
          };
          release = lib.mkOption {
            type = lib.types.str;
            description = "Distro release (trixie, jammy) or 'upstream' for unmanaged builds.";
          };
          esm = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether Ubuntu ESM/ESM-apps fixes count as available.";
          };
          dpkg = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Debian/Ubuntu source package -> installed version.";
          };
          nix = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Nix-managed package -> version.";
          };
          upstream = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Manually managed/upstream package -> version.";
          };
        };
      });
      default = { };
      description = "Declared systems and package versions.";
    };

    extraAssets = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Additional assets merged from the flake or another module.";
    };

    extraAssetsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "JSON file with additional assets (external systems).";
    };

    freshRssDb = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/freshrss/users/wouter/db.sqlite";
      description = "FreshRSS SQLite database read read-only for advisory context.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vuln-radar";
      description = "Cache and state directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = duplicateHosts == [ ];
        message = "vuln-radar: dezelfde host staat zowel in assets als in extraAssets/extraAssetsFile: ${lib.concatStringsSep ", " duplicateHosts}";
      }
      {
        assertion = invalidHosts == [ ];
        message = "vuln-radar: ongeldige asset(s): ${lib.concatStringsSep ", " invalidHosts}. Elke host heeft een release, niet-lege versies en geen package in meerdere bronnen.";
      }
    ];

    environment.etc."vuln-radar/assets.json".text = assetsJson;

    users.groups.vuln-radar = { };
    users.users.vuln-radar = {
      isSystemUser = true;
      group = "vuln-radar";
      extraGroups = lib.optional (config.users.groups ? freshrss) "freshrss";
      home = cfg.dataDir;
    };

    systemd.services.vuln-radar = {
      description = "Version-aware CVE dashboard (vuln-radar)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "freshrss-config.service" ];
      wants = [ "freshrss-config.service" ];

      environment = {
        VULN_RADAR_ASSETS = "/etc/vuln-radar/assets.json";
        VULN_RADAR_DATA = cfg.dataDir;
        VULN_RADAR_PORT = toString cfg.port;
        FRESHRSS_DB = cfg.freshRssDb;
      };

      serviceConfig = {
        ExecStart = "${pkgs.python3.withPackages (ps: [ ps.python-debian ])}/bin/python3 ${./vuln-radar.py}";
        Restart = "on-failure";
        RestartSec = 5;
        User = "vuln-radar";
        Group = "vuln-radar";
        StateDirectory = "vuln-radar";
        WorkingDirectory = cfg.dataDir;

        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        ReadOnlyPaths = [ cfg.freshRssDb ];
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };
    };

    services.nginx.virtualHosts."vulns.toorren.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        extraConfig = ''
          auth_request /authelia;
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $groups $upstream_http_remote_groups;
          auth_request_set $name $upstream_http_remote_name;
          auth_request_set $email $upstream_http_remote_email;

          error_page 401 = @authelia_portal;

          proxy_set_header Remote-User $user;
          proxy_set_header Remote-Groups $groups;
          proxy_set_header Remote-Name $name;
          proxy_set_header Remote-Email $email;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };

      locations."@authelia_portal" = {
        extraConfig = ''
          return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
        '';
      };

      locations."/authelia" = {
        proxyPass = "http://127.0.0.1:9091/api/verify";
        extraConfig = ''
          internal;
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Forwarded-Method $request_method;
          proxy_set_header X-Forwarded-Uri $request_uri;
          proxy_set_header Content-Length "";
          proxy_pass_request_body off;
        '';
      };
    };
  };
}
