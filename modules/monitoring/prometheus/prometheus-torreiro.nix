{ lib, ... }:

{
  services.prometheus = {
    scrapeConfigs = lib.mkAfter [
      # Externe HTTPS checks (SSL certificaten + bereikbaarheid)
      {
        job_name = "blackbox-torreiro-external";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];

        file_sd_configs = [
          {
            files = [ "/etc/prometheus/customers/torreiro/probes/urls.yaml" ];
            refresh_interval = "5m";
          }
        ];

        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "localhost:9115"; }
          { target_label = "check_type"; replacement = "external"; }
        ];
      }

      # Interne localhost checks (backend service health)
      {
        job_name = "blackbox-torreiro-internal";
        metrics_path = "/probe";
        params.module = [ "http_2xx_internal" ];

        file_sd_configs = [
          {
            files = [ "/etc/prometheus/customers/torreiro/probes/urls-internal.yaml" ];
            refresh_interval = "5m";
          }
        ];

        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "localhost:9115"; }
          { target_label = "check_type"; replacement = "internal"; }
        ];
      }
    ];

    ruleFiles = lib.mkAfter [
      ./customers/torreiro/alerts/alert-ssl_expiration.yml
      ./customers/torreiro/alerts/alert-service_down.yml
    ];
  };

  # Plaats URL bestanden in /etc/prometheus
  environment.etc."prometheus/customers/torreiro/probes/urls.yaml" = {
    source = ./customers/torreiro/probes/urls.yaml;
    mode = "0644";
    user = "prometheus";
    group = "prometheus";
  };

  environment.etc."prometheus/customers/torreiro/probes/urls-internal.yaml" = {
    source = ./customers/torreiro/probes/urls-internal.yaml;
    mode = "0644";
    user = "prometheus";
    group = "prometheus";
  };
}
