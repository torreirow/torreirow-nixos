{ config, pkgs, ... }:

{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "blackbox-improvement_it";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        file_sd_configs = [
          {
            files = [ "/etc/prometheus/improvement_it-urls.yaml" ];
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

    ruleFiles = [ ./alerts/improvement_it.yml ];
  };

  environment.etc."prometheus/improvement_it-urls.yaml" = {
    source = ./probes/improvement_it/urls.yaml;
    mode = "0644";
    user = "prometheus";
    group = "prometheus";
  };
}

