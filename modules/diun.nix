{ lib, pkgs, ... }:

# Diun: meldt via Telegram (dezelfde bot en chat als Alertmanager) wanneer er voor
# een draaiende Docker-container een nieuwer image is. Diun werkt zelf niets bij;
# bijwerken blijft een bewuste handeling.
#
# Standaard kijkt Diun of de digest van de gebruikte tag verandert. Dat dekt de
# :latest/:stable-images. Een gepinde tag (vaultwarden 1.37.5) verandert nooit,
# dus daar laat een label Diun de hele repo volgen en melden bij een nieuwe
# versie-tag.

let
  # Containers met een eigen build (localhost/…, ghcr.io/torreirow/…): daar valt
  # bij een registry niets te ontdekken.
  eigenImages = [
    "baikal"
    "erugo"
    "invoiceplane"
    "it-tools"
    "markmysteps-api"
    "markmysteps-web"
  ];

  diunStart = pkgs.writeShellScript "diun-start" ''
    # Alertmanager's secrets passen niet 1-op-1: Diun haalt geen regeleinde van
    # het token af, wil de chat-ID's als JSON-lijst in een bestand, en negeert
    # DIUN_NOTIF_TELEGRAM_CHATIDS (getest met 4.31.0).
    umask 077
    tr -d '[:space:]' < "$CREDENTIALS_DIRECTORY/bot-token" > "$RUNTIME_DIRECTORY/bot-token"
    printf '["%s"]' "$(tr -d '[:space:]' < "$CREDENTIALS_DIRECTORY/chat-id")" \
      > "$RUNTIME_DIRECTORY/chat-ids.json"
    exec ${lib.getExe pkgs.diun} serve
  '';
in
{
  virtualisation.oci-containers.containers = lib.genAttrs eigenImages (_: {
    labels."diun.enable" = "false";
  }) // {
    vaultwarden.labels = {
      "diun.watch_repo" = "true";
      "diun.include_tags" = "^\\d+\\.\\d+\\.\\d+$";
      "diun.sort_tags" = "semver";
      "diun.max_tags" = "5";
    };
  };

  # Voor `diun image list` e.d.; die praten via gRPC met de draaiende dienst.
  environment.systemPackages = [ pkgs.diun ];

  systemd.services.diun = {
    description = "Diun: melding bij nieuwe container-images";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      TZ = "Europe/Amsterdam";
      # Standaard luistert de gRPC-server op alle interfaces.
      GRPC_AUTHORITY = "127.0.0.1:42286";
      DIUN_DB_PATH = "/var/lib/diun/diun.db";
      # Dagelijks om 07:30; geen melding bij de eerste controle van een image.
      DIUN_WATCH_SCHEDULE = "30 7 * * *";
      DIUN_WATCH_JITTER = "5m";
      DIUN_WATCH_FIRSTCHECKNOTIF = "false";
      DIUN_PROVIDERS_DOCKER = "true";
      DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT = "true";
      DIUN_NOTIF_TELEGRAM_TOKENFILE = "/run/diun/bot-token";
      DIUN_NOTIF_TELEGRAM_CHATIDSFILE = "/run/diun/chat-ids.json";
    };
    serviceConfig = {
      ExecStart = diunStart;
      DynamicUser = true;
      SupplementaryGroups = [ "docker" ];
      StateDirectory = "diun";
      RuntimeDirectory = "diun";
      LoadCredential = [
        "bot-token:/run/alertmanager/telegramBotToken"
        "chat-id:/run/alertmanager/telegramChatId"
      ];
      Restart = "on-failure";
      RestartSec = "30s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
