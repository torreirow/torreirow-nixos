{ lib, pkgs, ... }:

let
  # Home Assistant bearer token
  # TODO: Move to agenix for better security
  homeassistantToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI3ZDk4MDk2YWNhNTQ0N2JkOTM4MDQ5OTJhY2MxMWExMiIsImlhdCI6MTc3NDQ2ODkxNCwiZXhwIjoyMDg5ODI4OTE0fQ.6bDnoBPVHLGXR2w_QK0h2aRJDaw-YDVmNmAiyhx2bi0";

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
