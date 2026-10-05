{ config, lib, ... }:

{
  # Home Assistant long-lived access token (zonder "Bearer "-prefix; Prometheus zet dat zelf)
  age.secrets.homeassistant-prometheus-token = {
    file = ../../../secrets/homeassistant-prometheus-token.age;
    path = "/run/agenix/homeassistant-prometheus-token";
    owner = "prometheus";
    mode = "0400";
  };

  # promtool draait in de build-sandbox en ziet het tokenbestand niet; volledige check
  # zou falen op een ontbrekend bearer_token_file.
  services.prometheus.checkConfig = "syntax-only";

  services.prometheus.scrapeConfigs = lib.mkAfter [
    {
      job_name = "homeassistant";
      scrape_interval = "60s";
      metrics_path = "/api/prometheus";

      bearer_token_file = config.age.secrets.homeassistant-prometheus-token.path;

      static_configs = [{
        targets = [ "localhost:8123" ];
        labels = {
          instance = "homeassistant";
        };
      }];
    }
  ];
}
