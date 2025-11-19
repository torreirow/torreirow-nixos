{ pkgs, lib, ... }:

let
  dashboardsDir = ./dashboards;

  # ✅ Alleen echte directories als "klanten"
  customerDirs = builtins.filter (name:
    (builtins.readDir dashboardsDir)."${name}" == "directory"
  ) (builtins.attrNames (builtins.readDir dashboardsDir));

  # ✅ Maak voor elke klant een provider aan
  dashboardProviders = map (customer: {
    name = customer;
    folder = customer;
    type = "file";
    disableDeletion = false;
    editable = true;
    options.path = "/etc/grafana/dashboards/${customer}";
  }) customerDirs;

  # ✅ Maak environment.etc entries voor elke geldige JSON file in elke submap
  dashboardFiles = lib.flatten (
    map (customer:
      let
        files = builtins.filter (file:
          lib.hasSuffix ".json" file
        ) (builtins.attrNames (builtins.readDir "${dashboardsDir}/${customer}"));
      in
      map (file: {
        name = "grafana/dashboards/${customer}/${file}";
        value = {
          source = "${dashboardsDir}/${customer}/${file}";
          mode = "0644";
          user = "grafana";
          group = "grafana";
        };
      }) files
    ) customerDirs
  );

in {
  services.grafana = {
    enable = true;

    settings.server = {
      http_port = 3000;
      domain = "localhost";
      root_url = "http://localhost:3000";
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

  # ✅ Combineer alle dashboardbestanden correct
  environment.etc = lib.listToAttrs dashboardFiles;

  networking.firewall.allowedTCPPorts = [ 3000 ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "info@dutchyland.net";
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."torreirow.dutchyland.net" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
      };
    };
  };
}

