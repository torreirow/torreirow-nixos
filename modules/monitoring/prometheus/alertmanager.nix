{ config, pkgs, ... }:

{
  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;

    configuration = {
      global.resolve_timeout = "5m";

      route = {
        receiver = "slack-notifications";
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "3h";
      };

      receivers = [
        {
          name = "slack-notifications";
          slack_configs = [
            {
              send_resolved = true;
              channel = "#managed-services-alerts";
              api_url = "***REMOVED***";
              text = ''
                {{ range .Alerts }}
                *{{ .Annotations.summary }}*
                {{ .Annotations.description }}
                {{ end }}
              '';
            }
          ];
        }
      ];
    };
  };
}

