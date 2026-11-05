# Slaapstand op de IdeaPad 5 14ARE05 (BIOS DTCN24WW, alleen s2idle).
#
# Toetsen en touchpad wekken hem niet (de kernel zet IRQ1-wake uit vanwege een firmwarebug);
# de aan/uit-knop wel. Maar die wek-druk komt bij de kernel binnen als "orderly poweroff": nog
# vóór de processen ontdooien draait kernel.poweroff_cmd (systemctl poweroff valt dan terug op
# SIGRTMIN+4), en het uitzetten blijft hangen op de bevroren sessies. Gezien op 2026-11-05.
#
# Daarom: kernel.poweroff_cmd negeert een poweroff zolang de laptop in suspend is (markering
# /run/suspend-bezig, gezet vóór de slaap en weg na het wekken). Buiten de slaap zet het gewoon
# uit. Controle na het wekken: `journalctl -k | grep poweroff-na-wekken`.
{ config, lib, pkgs, ... }:

let
  marker = "/run/suspend-bezig";

  poweroffCmd = pkgs.writeShellScript "poweroff-na-wekken" ''
    if [ -e ${marker} ]; then
      echo "<4>poweroff-na-wekken: poweroff van de kernel tijdens suspend genegeerd" > /dev/kmsg
      exit 0
    fi
    exec ${config.systemd.package}/sbin/poweroff
  '';
in
{
  # De systemd-module zet dit al op systemd's poweroff; hier de wrapper eromheen.
  boot.kernel.sysctl."kernel.poweroff_cmd" = lib.mkForce "${poweroffCmd}";

  powerManagement.powerDownCommands = "touch ${marker}";
  powerManagement.resumeCommands = "rm -f ${marker}";
}
