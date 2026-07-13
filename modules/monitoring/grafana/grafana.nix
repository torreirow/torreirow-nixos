{ pkgs, lib, ... }:

let
  dashboardsDir = ./dashboards;

  # Alle subdirectories van ./dashboards (klantnamen)
  customerDirs =
    builtins.filter (name:
      (builtins.readDir dashboardsDir)."${name}" == "directory"
    ) (builtins.attrNames (builtins.readDir dashboardsDir));

  # Provisioning providers: één per klantmap
  dashboardProviders = map (customer: {
    name = customer;
    folder = customer;
    type = "file";
    disableDeletion = false;
    editable = true;
    options.path = "/etc/grafana/dashboards/${customer}";
  }) customerDirs;

  # Genereer één grote attrset voor environment.etc
  dashboardFiles =
    lib.foldl' lib.mergeAttrs {} (
      lib.concatMap (customer:
        let
          files =
            builtins.filter (file: lib.hasSuffix ".json" file)
            (builtins.attrNames (builtins.readDir "${dashboardsDir}/${customer}"));
        in
        map (file: {
          "grafana/dashboards/${customer}/${file}" = {
            source = "${dashboardsDir}/${customer}/${file}";
            mode = "0644";
            user = "grafana";
            group = "grafana";
          };
        }) files
      ) customerDirs
    );

in
{
  age.secrets.grafana-secret-key = {
    file = ../../../secrets/grafana-secret-key.age;
    path = "/run/secrets/grafana-secret-key";
    owner = "grafana";
    mode = "0400";
  };

  users.users.grafana.extraGroups = [ "keys" ];

  services.grafana = {
    enable = true;

    settings.security.secret_key = "$__file{/run/secrets/grafana-secret-key}";

    settings.server = {
      http_port = 3000;
      domain = "toorren.net";
      root_url = "http://192.168.2.52:3000";
    };

    settings."auth.proxy" = {
      enabled = true;
      header_name = "X-WEBAUTH-USER";
      header_property = "username";
      auto_sign_up = true;
      whitelist = "127.0.0.1";
    };

    settings.users = {
      auto_assign_org_role = "Admin";
    };

    settings.auth = {
      disable_login_form = true;
    };

    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:9090";
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = dashboardProviders;
      };
    };

    declarativePlugins = with pkgs.grafanaPlugins; [
      grafana-piechart-panel
    ];
  };

  # Plaats dashboards in /etc/grafana/dashboards/*
  environment.etc = dashboardFiles;

  networking.firewall.allowedTCPPorts = [ 3000 ];


  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."grafana.dutchyland.net" = {
      forceSSL = true;
      useACMEHost = "toorren.net";
      locations."/" = {
        proxyPass = "http://0.0.0.0:3000";
      };
    };
  };
}

