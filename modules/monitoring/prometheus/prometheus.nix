{ pkgs, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9090;
    retentionTime = "60d";

    exporters.node.enable = true;
    globalConfig.scrape_interval = "30s";

    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [{ targets = [ "localhost:9090" ]; }];
      }
      {
        job_name = "node";
        static_configs = [{ targets = [ "localhost:9100" ]; }];
      }
    ];

    alertmanagers = [
      { static_configs = [{ targets = [ "localhost:9093" ]; }]; }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9090 9100 9115 ];
}

