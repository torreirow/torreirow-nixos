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

    settings = {
      # Luister extern op TCP+UDP 53
      server.listen = [
        "0.0.0.0@53"
        "::@53"
      ];

      # TSIG key voor ACME DNS-01
      key."acme-key" = {
        algorithm = "hmac-sha256";
        secret = "BASE64SECRET==";
      };

      # ACL die dynamic updates toestaat
      acl."acme-update" = {
        key = "acme-key";
        action = "update";
      };

      # De ENIGE definitie van de zone home.toorren.net
      zone."${zoneDef.zone}" = {
        file = zoneFile;
        acl = [ "acme-update" ];
      };
    };
  };

  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];
}

