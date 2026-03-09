{ config, pkgs, lib, ... }:

{
  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;

    configuration = {
      global.resolve_timeout = "5m";

      route = {
        receiver = "default";
        group_wait = "5s";
        group_interval = "30s";
        repeat_interval = "1m";
      };

      receivers = [
        {
          name = "default";
          # Geen configuratie = alerts worden ontvangen maar niet verstuurd
        }
      ];
    };
  };
}
