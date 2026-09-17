# NetworkManager-profiel voor de reMarkable-USB-gadget (lobos)
#
# Hoort bij de home-manager-module home/module/remarkable-sync. Zonder dit
# profiel is het apparaat onbereikbaar: NetworkManager laat de gadget-interface
# op `disconnected` staan terwijl de link er wél is, en probeert geen DHCP:
#
#   GENERAL.STATE:              30 (disconnected)
#   GENERAL.REASON:             40 (Carrier/link changed)
#   WIRED-PROPERTIES.CARRIER:   on
#
# LET OP -- gebruik NOOIT een kaal `nmcli device connect <interface>` om dit
# handmatig te forceren. NetworkManager kiest dan een willekeurig passend
# wired-profiel: op 2026-09-16 greep het `ethernet-eth1`, het profiel dat op dat
# moment in gebruik was door de ethernet-adapter van het dock, waarna `eth0` zijn
# verbinding verloor.
#
# Vastgezet op MAC-adres, niet op interfacenaam, om twee redenen:
#   1. De interfacenaam is padgebaseerd (`enp100s0f3u2c2` = USB-poort 1-2) en
#      verandert zodra het apparaat in een andere poort gaat.
#   2. Een MAC-gebonden profiel kan per definitie geen andere interface kapen --
#      de fout hierboven is er structureel mee uitgesloten.
#
# Het MAC van de gadget is stabiel: over 65 enumeraties in 20 uur kwam
# uitsluitend 7a:17:67:41:44:36 voorbij.
#
# `ensureProfiles` schrijft naar /run/NetworkManager/system-connections/ en doet
# alleen `nmcli connection reload`; bestaande profielen in /etc blijven ongemoeid.
{ ... }:

{
  networking.networkmanager.ensureProfiles.profiles = {
    remarkable-usb = {
      connection = {
        id = "remarkable-usb";
        uuid = "173f9c9f-15a2-4be8-8e28-84baa9b794cf";
        type = "ethernet";
        autoconnect = true;
      };

      # Geen interface-name: matchen gebeurt uitsluitend op dit MAC.
      ethernet = {
        mac-address = "7A:17:67:41:44:36";
      };

      # De reMarkable draait zelf een DHCP-server en deelt een adres uit in
      # 10.11.99.0/27; het apparaat zelf zit op 10.11.99.1.
      ipv4 = {
        method = "auto";
        # Het is een point-to-point linkje naar één apparaat: geen default route
        # en geen DNS van het tablet overnemen.
        never-default = true;
        ignore-auto-dns = true;
      };

      ipv6 = {
        method = "disabled";
      };
    };
  };
}
