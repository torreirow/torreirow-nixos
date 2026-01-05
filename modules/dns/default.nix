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

  # TSIG secret (1x bron)
  tsigSecret =
  lib.removeSuffix "\n"
    (builtins.readFile config.age.secrets.rfc2136.path);

in
{
  #### Secrets ####
  age.secrets.rfc2136 = {
    file = ../secrets/rfc2136.age;
    owner = "root";
    mode = "0400";
  };

  #### Knot DNS ####
  services.knot = {
    enable = true;

    settings = {
      server.listen = [
        "0.0.0.0@53"
        "::@53"
      ];

      # TSIG key voor ACME
      key."acme-key" = {
        algorithm = "hmac-sha256";
        secret = tsigSecret;
      };

      # ACL die updates toestaat
      acl."acme-update" = {
        key = "acme-key";
        action = "update";
      };

      # Zone definitie
      zone."${zoneDef.zone}" = {
        file = zoneFile;
        acl = [ "acme-update" ];
      };
    };
  };

  #### Firewall ####
  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];
}

