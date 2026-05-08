{ lib, pkgs, ... }:

let
  # Home Assistant bearer token
  # TODO: Move to agenix for better security
  homeassistantToken = "***REMOVED***";

  # Don't include "Bearer " prefix - Prometheus adds it automatically
  tokenFile = pkgs.writeText "homeassistant-bearer-token" homeassistantToken;
in
{
  services.prometheus.scrapeConfigs = lib.mkAfter [
    {
      job_name = "homeassistant";
      scrape_interval = "60s";
      metrics_path = "/api/prometheus";

      # Use bearer token authentication
      bearer_token_file = toString tokenFile;

      static_configs = [{
        targets = [ "localhost:8123" ];
        labels = {
          instance = "homeassistant";
        };
      }];
    }
  ];
}
