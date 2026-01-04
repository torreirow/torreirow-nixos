{ config, lib, pkgs, ... }:

let
  zoneDef = import ./dns-zone-home_toorren_net.nix { inherit lib; };

  zoneFile = pkgs.writeText "${zoneDef.zone}.zone" ''
    $TTL 300
    @ IN SOA ${zoneDef.soa.mname} ${zoneDef.soa.rname} (
      ${toString zoneDef.soa.serial}
      ${toString zoneDef.soa.refresh}
      ${toString zoneDef.soa.retry}
      ${toString zoneDef.soa.expire}
      ${toString zoneDef.soa.minimum}
    )

    ${lib.concatStringsSep "\n" (map (ns: "@ IN NS ${ns}") zoneDef.ns)}

    ${lib.concatStringsSep "\n" (map (r:
      "${r.name} IN ${r.type} ${r.value}"
    ) zoneDef.records)}
  '';
in
{
  services.knot = {
    enable = true;
    listen = [ "0.0.0.0@53" "::@53" ];

    zones = {
      "${zoneDef.zone}" = {
        file = zoneFile;
      };
    };
  };

  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];
}

