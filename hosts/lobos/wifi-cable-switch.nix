# Wifi uit zodra lobos op de kabel zit (lobos)
#
# Met kabel én wifi actief zitten beide interfaces in hetzelfde subnet
# (192.168.2.0/24) met elk een default route. Dat geeft ARP-/routeringsgedoe:
# verbindingen vallen weg en zelfs ping naar buiten faalt.
#
# Deze NetworkManager-dispatcher zet de wifi-radio uit zodra een ethernet-device
# met een default route actief is, en weer aan als dat er niet meer is.
# "Met een default route" is bewust: de reMarkable-USB-gadget is ook type
# ethernet, maar heeft `never-default` (zie remarkable-network.nix) en mag de
# wifi dus niet uitzetten.
{ pkgs, ... }:

{
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "wifi-cable-switch" ''
        export PATH=${pkgs.lib.makeBinPath [ pkgs.networkmanager pkgs.iproute2 pkgs.gawk pkgs.coreutils pkgs.util-linux ]}

        case "$2" in
          up|down|pre-down|connectivity-change) ;;
          *) exit 0 ;;
        esac

        wired=0
        for dev in $(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2=="ethernet" && $3=="connected" {print $1}'); do
          # Bij pre-down/down telt het device dat net weggaat niet meer mee.
          if [ "$dev" = "$1" ] && [ "$2" != "up" ]; then continue; fi
          if [ -n "$(ip route show default dev "$dev")" ]; then
            wired=1
          fi
        done

        if [ "$wired" = 1 ]; then
          [ "$(nmcli radio wifi)" = "enabled" ] && logger -t wifi-cable-switch "kabel actief: wifi uit" && nmcli radio wifi off
        else
          [ "$(nmcli radio wifi)" = "disabled" ] && logger -t wifi-cable-switch "geen kabel: wifi aan" && nmcli radio wifi on
        fi
        exit 0
      '';
    }
  ];
}
