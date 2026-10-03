{ config, pkgs, lib, unstable, ... }:

let
  format = pkgs.formats.yaml { };

  # Mutabele overlays leven op de externe schijf (backup via rustic).
  overlayBase = "/data/external/blocky";

  # Blocking-policy los van de service-infra (zie blocking.nix).
  blockingDef = import ./blocking.nix { inherit overlayBase; };

  # Alle NIET-geheime blocky-settings. De queryLog-sectie staat hier bewust niet:
  # blocky kent géén file:-referentie voor queryLog.target, dus de DSN wordt pas bij
  # runtime in de config gerenderd (zie renderBlockyConfig).
  blockyBaseSettings = {
    ports = {
      # LAN-resolver: blocky luistert op alle interfaces; de firewall opent 53
      # uitsluitend op de LAN-interface (zie networking.firewall.interfaces hieronder).
      dns = "0.0.0.0:53";
      # REST-API + statistieken voor blocky-ui. 0.0.0.0 zodat de container het via
      # host.docker.internal bereikt; poort 4000 wordt NIET in de firewall geopend,
      # dus host + docker-bridge only, nooit via nginx, nooit publiek.
      http = "0.0.0.0:4000";
    };

    upstreams.groups.default = [
      "1.1.1.1"   # Cloudflare
      "1.0.0.1"   # Cloudflare secundair
      "8.8.8.8"   # Google
      "8.8.4.4"   # Google secundair
    ];

    blocking = blockingDef.settings;

    # Intern (op :4000, firewall-dicht). Nooit publiek ontsloten.
    prometheus.enable = true;
    # Statistieken-API voor de overzichtskaarten van blocky-ui (vanaf blocky 0.30+;
    # vandaar de package-override naar 0.35). Reset bij een blocky-herstart.
    statistics.enable = true;
  };

  blockyBaseYaml = format.generate "blocky-base.yaml" blockyBaseSettings;

  # Config-template = base + queryLog-blok met een placeholder voor de DSN.
  # Single-quoted, zodat elke DSN zonder single-quote een geldige yaml-scalar blijft.
  blockyConfigTemplate = pkgs.runCommand "blocky-config-template.yaml" { } ''
    {
      cat ${blockyBaseYaml}
      echo "queryLog:"
      echo "  type: mysql"
      echo "  logRetentionDays: 7"
      echo "  target: '@QUERYLOG_DSN@'"
    } > "$out"
  '';

  # Rendert bij runtime /run/blocky/config.yaml met de DSN uit de systemd-credential.
  # Draait als de service-gebruiker (DynamicUser): leest $CREDENTIALS_DIRECTORY
  # (door LoadCredential leesbaar gemaakt) en schrijft in $RUNTIME_DIRECTORY.
  # Literal string-replace via python3 — geen regex, dus geen escaping-valkuilen
  # met de &, / en ( ) in de DSN.
  renderBlockyConfigPy = pkgs.writeText "blocky-render.py" ''
    import os
    dsn = open(os.path.join(os.environ["CREDENTIALS_DIRECTORY"], "querylog-dsn")).read()
    tpl = open("${blockyConfigTemplate}").read()
    out = os.path.join(os.environ["RUNTIME_DIRECTORY"], "config.yaml")
    open(out, "w").write(tpl.replace("@QUERYLOG_DSN@", dsn))
  '';

  renderBlockyConfig = pkgs.writeShellScript "blocky-render-config" ''
    set -eu
    umask 077
    exec ${pkgs.python3}/bin/python3 ${renderBlockyConfigPy}
  '';

  # Helper: lijsten live herladen zonder restart/rebuild (loopback-API).
  blockyRefresh = pkgs.writeShellScriptBin "blocky-refresh" ''
    set -eu
    exec ${pkgs.curl}/bin/curl -fsS -X POST http://127.0.0.1:4000/api/lists/refresh
  '';

  # Statische blocky-ui config. Bevat GEEN geheim: alleen het wachtwoord komt via
  # een file:-referentie uit een read-only gemount agenix-secret (/config/db_password).
  blockyUiConfig = pkgs.writeText "blocky-ui.yml" ''
    servers:
      malandro:
        name: Malandro
        url: http://host.docker.internal:4000
        logs:
          source: mariadb

    logSources:
      mariadb:
        type: mysql
        # Object-vorm: host/port/user/db staan hier (niet geheim); alleen het
        # wachtwoord komt via een file:-referentie uit een gemount secret.
        target:
          host: host.docker.internal
          port: 3306
          username: blocky
          database: blocky
          password: file:/config/db_password

    instanceName: Blocky (malandro)
  '';
in
{
  #### Secrets ####
  # blocky (native) krijgt de volledige Go-driver-DSN via systemd LoadCredential;
  # blocky-ui (container) krijgt alleen het platte wachtwoord read-only gemount.
  # Geen van beide staat in de nix-store.
  age.secrets.blocky-querylog-dsn-host = {
    file = ../../secrets/blocky-querylog-dsn-host.age;
    path = "/run/agenix/blocky-querylog-dsn-host";
    owner = "root";
    mode = "0400";
  };
  age.secrets.blocky-db-password-ui = {
    file = ../../secrets/blocky-db-password-ui.age;
    path = "/run/agenix/blocky-db-password-ui";
    # 0444: dit bestand wordt read-only in de blocky-ui container gemount en moet
    # door het container-proces (onbekende uid) leesbaar zijn.
    owner = "root";
    mode = "0444";
  };

  #### Mutabele overlay-bestanden (sudo-bewerkbaar, door blocky gelezen) ####
  # Eén bestand per groep (blocky accepteert geen directory/glob als bron). tmpfiles
  # maakt ze leeg aan zodat de bron altijd bestaat; 0644 → bewerken met sudo, blocky
  # (DynamicUser) leest via o+r.
  systemd.tmpfiles.rules =
    [
      "d ${overlayBase} 0755 root root -"
      "d ${overlayBase}/denylists.d 0755 root root -"
      "d ${overlayBase}/allowlists.d 0755 root root -"
    ]
    ++ lib.concatMap (g: [
      "f ${overlayBase}/denylists.d/${g}.txt 0644 root root -"
      "f ${overlayBase}/allowlists.d/${g}.txt 0644 root root -"
    ]) blockingDef.overlayGroups;

  #### Refresh-helper ####
  environment.systemPackages = [ blockyRefresh ];

  #### LAN-cutover: DNS (53) alleen op de LAN-interface open ####
  # Blocky luistert op 0.0.0.0:53 (zie ports.dns); de firewall opent 53 uitsluitend
  # op enp3s0 (het thuisnetwerk), niet breder. Omkeerbaar: deze regels + ports.dns
  # terug naar 127.0.0.1 = weer local-only.
  networking.firewall.interfaces.enp3s0.allowedUDPPorts = [ 53 ];
  networking.firewall.interfaces.enp3s0.allowedTCPPorts = [ 53 ];

  #### Blocky (native DNS + ad-blocker) ####
  services.blocky = {
    enable = true;
    # blocky 0.35 uit de unstable-input: nixpkgs 26.05 pint 0.29, maar de
    # `statistics`-sectie (nodig voor de blocky-ui overzichtskaarten) bestaat pas
    # vanaf 0.30+. 0.35 is getest met deze config (validate OK).
    package = unstable.blocky;
    # De runtime-config (met queryLog-DSN) wordt pas bij service-start gerenderd;
    # de store-config zou geen queryLog bevatten, dus de build-check heeft geen zin.
    enableConfigCheck = false;
    settings = blockyBaseSettings;
  };

  # DSN als credential, config bij runtime renderen, en na MariaDB starten.
  # blocky leest de overlays op /data/external read-only; onder ProtectSystem=strict
  # is lezen toegestaan (geverifieerd via de overlay-test). Geen ReadOnlyPaths nodig —
  # dat zou bij een nog-niet-bestaand pad juist de service-start breken.
  systemd.services.blocky = {
    after = [ "mysql.service" ];
    wants = [ "mysql.service" ];
    serviceConfig = {
      LoadCredential = [
        "querylog-dsn:${config.age.secrets.blocky-querylog-dsn-host.path}"
      ];
      ExecStartPre = [ renderBlockyConfig ];
      ExecStart = lib.mkForce
        "${config.services.blocky.package}/bin/blocky --config /run/blocky/config.yaml";
    };
  };

  #### blocky-ui (beheer-dashboard, OCI container) ####
  virtualisation.oci-containers.containers.blocky-ui = {
    image = "ghcr.io/gabeduartem/blocky-ui:2.2.0";
    # Loopback: alleen via nginx + Authelia bereikbaar. Container luistert op 3000.
    ports = [ "127.0.0.1:8087:3000" ];
    environment = {
      TZ = "Europe/Amsterdam";
      BLOCKY_UI_CONFIG = "/config/blocky-ui.yml";
    };
    volumes = [
      "${blockyUiConfig}:/config/blocky-ui.yml:ro"
      "${config.age.secrets.blocky-db-password-ui.path}:/config/db_password:ro"
    ];
    extraOptions = [
      # Container bereikt blocky's API (:4000) en MariaDB (:3306) op de host.
      "--add-host=host.docker.internal:host-gateway"
    ];
    labels = {
      "app" = "blocky-ui";
      "description" = "BlockyUI - beheer-dashboard voor blocky DNS";
    };
  };

  #### Nginx reverse proxy (generieke forward-auth-triple, zoals ittools.nix) ####
  services.nginx.virtualHosts."blocky.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8087";
      proxyWebsockets = true;
      extraConfig = ''
        auth_request /authelia;
        error_page 401 = @authelia_portal;

        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };

    # Authelia redirect named location
    locations."@authelia_portal" = {
      extraConfig = ''
        return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    };

    # Authelia authentication endpoint
    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
      '';
    };
  };
}
