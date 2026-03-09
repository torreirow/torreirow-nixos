{ config, pkgs, lib, agenix, ... }:

{
  age.secrets.telegramBotToken = {
    file = ../../../secrets/module-monitoring-telegram_bot_token.age;
    path = "/run/alertmanager/telegramBotToken";
    owner = "alertmanager";
    group = "alertmanager";
    mode = "0400";
    symlink = false;
  };

  age.secrets.telegramChatId = {
    file = ../../../secrets/module-monitoring-telegram_chat_id.age;
    path = "/run/alertmanager/telegramChatId";
    owner = "alertmanager";
    group = "alertmanager";
    mode = "0400";
    symlink = false;
  };

  services.prometheus.alertmanager = {
    configuration = {
      route = {
        receiver = "telegram-notifications";
        group_wait = "5s";
        group_interval = "30s";
        repeat_interval = "1m";
      };

      receivers = [
        {
          name = "telegram-notifications";
          telegram_configs = [
            {
              send_resolved = true;
              bot_token_file = "/run/alertmanager/telegramBotToken";
              chat_id_file = "/run/alertmanager/telegramChatId";
              parse_mode = "HTML";
              message = ''
                {{ range .Alerts }}
                <b>{{ .Annotations.summary }}</b>
                {{ .Annotations.description }}

                Status: {{ .Status }}
                {{ if .Labels.severity }}Severity: {{ .Labels.severity }}{{ end }}
                {{ end }}
              '';
            }
          ];
        }
      ];
    };
  };
}
