{ config, pkgs, lib, agenix, ... }:

{
  age.secrets.slackWebhook = {
    file = ../../../secrets/module-monitoring-slack_webhook.age;
    path = "/run/alertmanager/slackWebhook";
    owner = "alertmanager";
    group = "alertmanager";
    mode = "0400";
    symlink = false;
  };

  services.prometheus.alertmanager = {
    configuration = {
      route = {
        receiver = "slack-notifications";
        group_wait = "5s";
        group_interval = "30s";
        repeat_interval = "1m";
      };

      receivers = [
        {
          name = "slack-notifications";
          slack_configs = [
            {
              send_resolved = true;
              channel = "#managed-services-alerts";
              api_url_file = "/run/alertmanager/slackWebhook";
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
