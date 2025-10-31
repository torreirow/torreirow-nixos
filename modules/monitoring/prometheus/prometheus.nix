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
      {
        job_name = "blackbox";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        file_sd_configs = [
          {
            files = [ "/etc/prometheus/urls.yaml" ];
            refresh_interval = "5m";
          }
        ];
        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "localhost:9115"; }
        ];
      }
    ];

    alertmanagers = [
      {
        static_configs = [{ targets = [ "localhost:9093" ]; }];
      }
    ];

    ruleFiles = [
      ./alerts/alert-rules.yml
    ];
  };

  environment.etc."prometheus/urls.yaml" = {
    source = ./urls.yaml;
    mode = "0644";
    user = "prometheus";
    group = "prometheus";
  };

  networking.firewall.allowedTCPPorts = [ 9090 9100 9115 ];
}

