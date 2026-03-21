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
    enable = true;
    port = 9093;

    configuration = {
      global.resolve_timeout = "5m";

      route = {
        receiver = "telegram-notifications";
        # group_wait: Wacht dit lang voordat de eerste notificatie wordt verstuurd
        # (om meerdere alerts tegelijk te groeperen)
        group_wait = "30s";

        # group_interval: Wacht dit lang tussen updates van een groep alerts
        group_interval = "5m";

        # repeat_interval: Stuur GEEN herhaalde notificaties (effectief "eenmalig")
        # 8760h = 1 jaar, dus praktisch gezien geen repeats
        repeat_interval = "8760h";
      };

      receivers = [
        {
          name = "telegram-notifications";
          telegram_configs = [
            {
              send_resolved = true;
              bot_token_file = "/run/alertmanager/telegramBotToken";
              chat_id = 1522117;  # Direct chat ID (from secret file content)
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
