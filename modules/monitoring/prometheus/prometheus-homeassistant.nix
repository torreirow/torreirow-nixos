{ lib, config, ... }:

{
  # Home Assistant Prometheus scrape configuration
  # IMPORTANT: Create a long-lived access token in Home Assistant first!
  # Profile → Long-Lived Access Tokens → CREATE TOKEN (name: prometheus)

  # Create secret file for the token
  # echo "Bearer YOUR_TOKEN_HERE" | sudo tee /var/lib/prometheus/homeassistant-bearer-token

  services.prometheus.scrapeConfigs = lib.mkAfter [
    {
      job_name = "homeassistant";
      scrape_interval = "60s";
      metrics_path = "/api/prometheus";

      # Use bearer token authentication
      bearer_token_file = "/var/lib/prometheus/homeassistant-bearer-token";

      static_configs = [{
        targets = [ "localhost:8123" ];
        labels = {
          instance = "homeassistant";
        };
      }];
    }
  ];

  # Create directory for token file
  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus 0755 prometheus prometheus -"
  ];
}
