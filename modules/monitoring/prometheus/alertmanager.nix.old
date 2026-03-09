{ config, pkgs, lib, agenix, ... }:

{


#  systemd.tmpfiles.rules = [
#    "d /run/alertmanager 0750 alertmanager alertmanager -"
#  ];

  age.secrets.slackWebhook = {
    file = ../../../secrets/module-monitoring-slack_webhook.age;
    path = "/run/alertmanager/slackWebhook";
    owner = "alertmanager"; 
    group = "alertmanager";
    mode = "0400";
    symlink = false;
};

  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;

    configuration = {
      global.resolve_timeout = "5m";

      route = {
        receiver = "slack-notifications";
#        group_wait = "30s";
#        group_interval = "5m";
#        repeat_interval = "3h";
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
              #api_url_file = config.age.secrets.slackWebhook.path;
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

