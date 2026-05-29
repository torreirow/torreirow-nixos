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

  # Declareer alertmanager als statische system user zodat agenix secrets
  # kan chownen voor de service start (dynamic users bestaan pas na service start)
  users.users.alertmanager = {
    isSystemUser = true;
    group = "alertmanager";
  };
  users.groups.alertmanager = {};

  # Schakel DynamicUser uit zodat de statische alertmanager user gebruikt wordt
  # (DynamicUser=yes maakt een ephemere user met andere UID, kan secrets niet lezen)
  systemd.services.alertmanager.serviceConfig.DynamicUser = lib.mkForce false;
  systemd.services.alertmanager.serviceConfig.User = lib.mkForce "alertmanager";
  systemd.services.alertmanager.serviceConfig.Group = lib.mkForce "alertmanager";

  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;

    configuration = {
      global.resolve_timeout = "5m";

      route = {
        receiver = "all-notifications";
        # Elke alert type krijgt een eigen groep
        group_by = [ "alertname" ];
        # group_wait: Wacht dit lang voordat de eerste notificatie wordt verstuurd
        group_wait = "30s";
        # group_interval: Wacht dit lang tussen updates van een groep alerts
        group_interval = "5m";
        # repeat_interval: Stuur GEEN herhaalde notificaties (effectief "eenmalig")
        # 8760h = 1 jaar, dus praktisch gezien geen repeats
        repeat_interval = "8760h";
      };

      receivers = [
        {
          name = "all-notifications";
          telegram_configs = [
            {
              send_resolved = true;
              bot_token_file = "/run/alertmanager/telegramBotToken";
              chat_id = 1522117;
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
          webhook_configs = [
            {
              send_resolved = true;
              url = "https://opsknight.toorren.net/api/integrations/prometheus?integrationId=cmpo90y9t0003j9xhtigxheq7&integrationKey=ef5e61551cff167c339c5f3dc5943e77";
            }
          ];
        }
      ];
    };
  };
}
