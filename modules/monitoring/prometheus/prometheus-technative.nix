{ config, pkgs, ... }:

{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "blackbox-technative";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        file_sd_configs = [
          {
            files = [ "/etc/prometheus/technative-urls.yaml" ];
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

    ruleFiles = [ ./alerts/technative.yml ];
  };

  environment.etc."prometheus/technative-urls.yaml" = {
    source = ./probes/technative/urls.yaml;
    mode = "0644";
    user = "prometheus";
    group = "prometheus";
  };
}

