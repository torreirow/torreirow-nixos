{ config, pkgs, lib, agenix, ... }:

{
  age.secrets.slackWebhook.file = ../../../secrets/module-monitoring-slack_webhook.age;

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
              api_url_file = config.age.secrets.slackWebhook.path;
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

