{ config, lib, pkgs, ... }:

# Ochtend-wake van bobadela1 (Nextcloud AIO) vanaf de altijd-aan host malandro.
# bobadela1 gaat elke avond 23:00 uit (hosts/bobadela1/nightly-shutdown.*); deze
# service is het complement: elke ochtend 09:00 wekken via Wake-on-LAN, 30 min
# blijven proberen (burst/5 min), pas klaar als Nextcloud gezond is, en bij falen
# een Signal-melding sturen. Zie OpenSpec-change add-bobadela1-wake.
#
# Het wake-script (modules/wake-bobadela1/wake-bobadela1.py) is de gedeelde bron:
# deze systeem-service draait het via de store-path (geen afhankelijkheid van
# /home), en home/module/wake-bobadela1 legt hetzelfde script neer als
# ~/bin/wake-bobadela1 voor handmatig gebruik.

let
  wake = pkgs.writeShellScriptBin "wake-bobadela1" ''
    export PATH=${lib.makeBinPath [ pkgs.iputils ]}''${PATH:+:$PATH}
    exec ${pkgs.python3}/bin/python3 ${./wake-bobadela1.py} "$@"
  '';
in
{
  systemd.services.wake-bobadela1 = {
    description = "Wek bobadela1 via Wake-on-LAN tot Nextcloud gezond is (Signal bij falen)";
    # network-online zodat de broadcast + status.php-check kunnen; best-effort.
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      # 30 min proberen, WoL-burst elke 5 min, Nextcloud-check als succescriterium,
      # Signal-melding bij falen.
      ExecStart = "${wake}/bin/wake-bobadela1 --wait 1800 --burst 300 --check-nextcloud --notify";
      # Ruim boven de 30-min-lus zodat systemd de service niet vroegtijdig kapt.
      TimeoutStartSec = "35min";
    };
  };

  systemd.timers.wake-bobadela1 = {
    description = "Dagelijkse ochtend-wake van bobadela1 (09:00)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 09:00:00";
      Persistent = true;
    };
  };
}
