# RustDesk zonder publieke relay: Wouter verbindt vanaf lobos met het Nebula-IP van mpenzi
# (10.77.0.3) op poort 21118. Die poort staat alleen open op de Nebula-interface en alleen
# voor host lobos (modules/nebula.nix); op wifi/LAN blijft hij dicht.
#
# nixpkgs levert voor de client geen service. Deze unit doet wat het upstream .deb-pakket
# doet (`rustdesk --service` als root); die service start per sessie het server-proces dat
# inkomende verbindingen aanneemt, ook als Maaike het venster niet open heeft.
{ config, lib, pkgs, ... }:

let
  rustdesk = pkgs.rustdesk-flutter;
in
{
  environment.systemPackages = [ rustdesk ];

  systemd.services.rustdesk = {
    description = "RustDesk";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" "display-manager.service" ];
    # Direct IP access als systeem-default. RustDesk bewaart opties van de service in de
    # config van root; we zetten de optie alleen als hij er nog niet staat, zodat een
    # bewuste keuze in de GUI blijft staan. Controle na deploy: zie docs/mpenzi.md.
    preStart = ''
      cfg=/root/.config/rustdesk/RustDesk2.toml
      mkdir -p "$(dirname "$cfg")"
      touch "$cfg"
      if ! grep -q '^direct-server' "$cfg"; then
        if grep -q '^\[options\]' "$cfg"; then
          sed -i "/^\[options\]/a direct-server = 'Y'" "$cfg"
        else
          printf "\n[options]\ndirect-server = 'Y'\n" >> "$cfg"
        fi
      fi
    '';
    path = [ pkgs.gnugrep pkgs.gnused pkgs.coreutils ];
    serviceConfig = {
      ExecStart = "${lib.getExe rustdesk} --service";
      Restart = "always";
      RestartSec = 5;
      KillMode = "mixed";
      TimeoutStopSec = 30;
      LimitNOFILE = 100000;
    };
  };
}
