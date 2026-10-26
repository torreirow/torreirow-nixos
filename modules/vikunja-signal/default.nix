{ config, lib, pkgs, ... }:

# Vikunja-webhooks → Signal. Vikunja (modules/vikunja.nix) POST herinneringen
# (task.reminder.fired) en verlopen taken (tasks.overdue) naar deze ontvanger op
# 127.0.0.1:8100; die controleert de HMAC-handtekening en stuurt een bericht via
# de lokale signal-cli REST API (modules/signal-cli.nix, poort 8088).
#
# De webhook zelf configureer je in Vikunja als gebruiker: Instellingen → Webhooks,
# doel-URL http://127.0.0.1:8100/, geheim = VIKUNJA_WEBHOOK_SECRET uit
# /run/agenix/vikunja-webhook-secret. Zie docs/vikunja-signal.md.

let
  port = 8100;
  receiver = pkgs.writeShellScript "vikunja-signal" ''
    exec ${pkgs.python3}/bin/python3 ${./vikunja-signal.py}
  '';
in
{
  imports = [ ../signal-numbers.nix ];

  # Env-bestand: VIKUNJA_WEBHOOK_SECRET=<zelfde geheim als in de Vikunja-webhook>
  age.secrets.vikunja-webhook-secret = {
    file = ../../secrets/vikunja-webhook-secret.age;
    path = "/run/agenix/vikunja-webhook-secret";
    mode = "0400";
  };

  services.vikunja.settings = {
    webhooks.enabled = true;
    # Vikunja's SSRF-bescherming weigert standaard webhooks naar 127.0.0.1.
    # Registratie staat uit, dus alleen eigen accounts kunnen webhooks aanmaken.
    outgoingrequests.allownonroutableips = true;
  };

  systemd.services.vikunja-signal = {
    description = "Vikunja-webhooks doorsturen naar Signal";
    after = [ "network.target" "docker-signal-cli.service" ];
    wantedBy = [ "multi-user.target" ];
    environment.LISTEN_PORT = toString port;
    serviceConfig = {
      ExecStart = receiver;
      EnvironmentFile = [
        config.age.secrets.signal-numbers.path
        config.age.secrets.vikunja-webhook-secret.path
      ];
      Restart = "on-failure";
      RestartSec = 5;

      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      IPAddressAllow = [ "localhost" ];
      IPAddressDeny = "any";
    };
  };
}
