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

  # OIDC client-secret (plat) waarmee Grafana zich bij Authelia legitimeert.
  age.secrets.grafana-oidc-secret = {
    file = ../../../secrets/grafana-oidc-secret.age;
    path = "/run/secrets/grafana-oidc-secret";
    owner = "grafana";
    mode = "0400";
  };

  users.users.grafana.extraGroups = [ "keys" ];

  services.grafana = {
    enable = true;

    settings.security.secret_key = "$__file{/run/secrets/grafana-secret-key}";

    settings.server = {
      http_port = 3000;
      domain = "grafana.toorren.net";
      # Publieke URL: Grafana doet nu zelf de OIDC-redirect, dus de root_url moet
      # het publieke adres zijn (anders klopt de redirect_uri niet).
      root_url = "https://grafana.toorren.net";
    };

    # OIDC via Authelia vervangt de oude auth.proxy (waarbij IEDEREEN die binnenkwam
    # org-Admin werd). De rol volgt nu uit de groep via role_attribute_path:
    # grafana-admins -> Admin, grafana-editors -> Editor, anders Viewer.
    settings."auth.generic_oauth" = {
      enabled = true;
      name = "Authelia";
      icon = "signin";
      client_id = "grafana";
      client_secret = "$__file{/run/secrets/grafana-oidc-secret}";
      scopes = "openid profile email groups";
      empty_scopes = false;
      auth_url = "https://auth.toorren.net/api/oidc/authorization";
      token_url = "https://auth.toorren.net/api/oidc/token";
      api_url = "https://auth.toorren.net/api/oidc/userinfo";
      login_attribute_path = "preferred_username";
      groups_attribute_path = "groups";
      name_attribute_path = "name";
      use_pkce = true;
      # JMESPath: eerste match wint. role_attribute_strict blijft uit, zodat een
      # gebruiker zonder match op Viewer valt i.p.v. geweigerd te worden.
      role_attribute_path = "contains(groups[*], 'grafana-admins') && 'Admin' || contains(groups[*], 'grafana-editors') && 'Editor' || 'Viewer'";
    };

    # Ingebouwde admin-loginvorm BEWUST aan laten als vangnet: als de OIDC-flow
    # hapert kun je nog als Grafana-admin (DB) inloggen. auto_assign_org_role weg
    # (geen automatische Admin meer); nieuwe OIDC-users krijgen hun rol uit de groep.
    settings.auth = {
      disable_login_form = false;
      oauth_auto_login = false;
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

