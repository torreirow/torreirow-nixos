{ config, pkgs, lib, ... }:

{

services.prometheus.exporters.blackbox = {
  enable = true;
  port = 9115;
  configFile = pkgs.writeText "blackbox.yml" ''
    modules:
      http_2xx:
        prober: http
        timeout: 15s
        http:
          fail_if_not_ssl: true
          ip_protocol_fallback: false
          method: GET
          no_follow_redirects: false
          preferred_ip_protocol: "ip4"
          valid_http_versions:
            - "HTTP/1.1"
            - "HTTP/2.0"
  '';
};


services.prometheus = {
  enable = true;
  port = 9090;

  exporters = {
    node.enable = true;

  };

  scrapeConfigs = [
    {
      job_name = "prometheus";
      static_configs = [{ targets = [ "localhost:9090" ]; }];
    }
    {
      job_name = "node";
      static_configs = [{ targets = [ "localhost:9100" ]; }];
    }
    {
      job_name = "blackbox";
      metrics_path = "/probe";
      params.module = [ "http_2xx" ];
      static_configs = [
        { targets = [ "https://www.nu.nl" "https://technative.eu" ]; }
      ];
      relabel_configs = [
        { source_labels = [ "__address__" ]; target_label = "__param_target"; }
        { source_labels = [ "__param_target" ]; target_label = "instance"; }
        { target_label = "__address__"; replacement = "localhost:9115"; }
      ];
    }
  ];
};

  # Voeg dit toe om SSL_CERT_FILE goed te zetten voor de blackbox exporter
  systemd.services.prometheus-blackbox-exporter.serviceConfig.Environment = [
    "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
  ];


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
      dashboards = {
        settings = {
          apiVersion = 1;
          providers = [
            {
              name = "Default";
              orgId = 1;
              folder = "";
              type = "file";
              disableDeletion = false;
              editable = true;
              options = {
                path = "/var/lib/grafana/dashboards";
              };
            }
          ];
        };
      };
    };
    declarativePlugins = with pkgs.grafanaPlugins; [
      grafana-piechart-panel
    ];
  };

  # Create the dashboard file in the Grafana dashboards directory
  environment.etc."grafana/dashboards/testwouter.json" = {
    source = ../dashboards/grafana-dashboard-testwouter.json;
    mode = "0644";
    user = "grafana";
    group = "grafana";
  };

  # Make sure the dashboards directory exists and is writable by Grafana
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "L+ /var/lib/grafana/dashboards/testwouter.json - - - - /etc/grafana/dashboards/testwouter.json"
  ];


  networking.firewall.allowedTCPPorts = [ 3000 9090 9100 9115 ];
}

