{ pkgs, lib, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9090;
    retentionTime = "60d";

    exporters.node = {
      enable = true;
      enabledCollectors = [ "textfile" ];
      extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-textfiles" ];
    };

    globalConfig.scrape_interval = "30s";

    # Basis-scrapes voor Prometheus zelf en de node exporter
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
        job_name = "vulnix";
        static_configs = [{ targets = [ "localhost:9109" ]; }];
      }

    ];

    # Laat klantmodules extra scrapes toevoegen
    alertmanagers = [
      {
        static_configs = [{ targets = [ "localhost:9093" ]; }];
      }
    ];

    # Algemene regels of alerts
    # Gebruik lib.mkBefore zodat andere modules hier extra alerts aan kunnen toevoegen
    ruleFiles = lib.mkBefore [
      ./alerts/test-alerts.yml
      ./alerts/service-alerts.yml
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9090 9100 9115 9109];

  # Directory voor textfile collector metrics
  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus-node-exporter-textfiles 0755 node-exporter node-exporter -"
  ];
}

