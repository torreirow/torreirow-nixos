{ pkgs, ... }:
{
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
        providers = [
          {
            name = "Default";
            orgId = 1;
            folder = "";
            type = "file";
            disableDeletion = false;
            editable = true;
            options.path = "/etc/grafana/dashboards";
          }
        ];
      };
    };

    declarativePlugins = with pkgs.grafanaPlugins; [
      grafana-piechart-panel
    ];
  };

  environment.etc."grafana/dashboards/technative-urls.json" = {
    source = ./dashboards/technative-urls.json;
    mode = "0644";
    user = "grafana";
    group = "grafana";
  };

  networking.firewall.allowedTCPPorts = [ 3000 ];
}

