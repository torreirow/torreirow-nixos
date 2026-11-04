# Nebula-mesh "toorren": lighthouse malandro, nodes lobos en mpenzi (zie docs/mpenzi.md).
#
# Alleen eigen overlay-verkeer over 10.77.0.0/24; het gewone internetverkeer van een host
# loopt er niet doorheen. Het host-adres en de inbound-regels staan centraal in `hosts`
# hieronder, zodat het hele toegangsbeleid op één plek leesbaar is.
#
# Certificaten komen uit agenix (secrets/nebula-ca.crt.age, nebula-<host>.{crt,key}.age).
# Die maakt de beheerder zelf (handmatige stap). Zolang ze niet in de repo staan, blijft
# Nebula uit en geeft de build alleen een warning; de host bouwt dus gewoon.
{ config, lib, ... }:

let
  cfg = config.toorren.nebula;
  netName = "toorren";
  host = config.networking.hostName;

  lighthouse = "malandro";

  # IP per host plus de extra inbound-regels bovenop ICMP. Nebula-firewall matcht op de
  # naam in het certificaat (`host`), dus `nebula-cert sign -name lobos` is hier lobos.
  hosts = {
    malandro = { ip = "10.77.0.1"; inbound = [ ]; };
    lobos = { ip = "10.77.0.2"; inbound = [ ]; };
    mpenzi = {
      ip = "10.77.0.3";
      inbound = [
        { port = 22; proto = "tcp"; host = "lobos"; }      # ssh voor beheer
        { port = 21118; proto = "tcp"; host = "lobos"; }   # RustDesk direct IP
      ];
    };
  };

  isLighthouse = host == lighthouse;
  lighthouseIp = hosts.${lighthouse}.ip;

  ageFiles = {
    ca = ../secrets/nebula-ca.crt.age;
    cert = ../secrets + "/nebula-${host}.crt.age";
    key = ../secrets + "/nebula-${host}.key.age";
  };
  haveAgeFiles = lib.all builtins.pathExists (lib.attrValues ageFiles);

  owner = "nebula-${netName}";
  ageSecret = file: { inherit file owner; group = owner; mode = "0400"; };

  pki =
    if cfg.pki != null then cfg.pki
    else {
      ca = config.age.secrets.nebula-ca.path;
      cert = config.age.secrets.nebula-cert.path;
      key = config.age.secrets.nebula-key.path;
    };

  active = cfg.pki != null || haveAgeFiles;
in
{
  options.toorren.nebula = {
    enable = lib.mkEnableOption "de Nebula-mesh toorren";

    lighthouseEndpoints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # LAN-adres eerst (thuis, geen NAT-hairpin nodig), daarna het publieke adres.
      default = [ "192.168.2.52:4242" "wg.toorren.net:4242" ];
      description = "Underlay-adressen (host:poort) waarop de lighthouse bereikbaar is.";
    };

    pki = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
      default = null;
      description = ''
        Platte paden { ca, cert, key } in plaats van agenix. Alleen voor de VM-test;
        nooit met echte sleutels gebruiken, want die belanden dan in de store.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [{
        assertion = hosts ? ${host};
        message = "toorren.nebula: host '${host}' staat niet in de hosts-tabel van modules/nebula.nix.";
      }];
      warnings = lib.optional (!active)
        "toorren.nebula: secrets/nebula-{ca,${host}}.*.age ontbreken; Nebula staat uit tot de certificaten er zijn (zie docs/mpenzi.md).";
    }

    (lib.mkIf (cfg.pki == null && haveAgeFiles) {
      age.secrets = {
        nebula-ca = ageSecret ageFiles.ca;
        nebula-cert = ageSecret ageFiles.cert;
        nebula-key = ageSecret ageFiles.key;
      };
      # Op malandro/lobos lopen de agenix-paden via /run/keys (0750 root:keys).
      users.users.${owner}.extraGroups = [ "keys" ];
    })

    (lib.mkIf active {
      services.nebula.networks.${netName} = {
        enable = true;
        inherit (pki) ca cert key;
        inherit isLighthouse;
        # malandro is ook relay, voor als twee laptops achter NAT elkaar niet direct vinden.
        isRelay = isLighthouse;
        lighthouses = lib.optional (!isLighthouse) lighthouseIp;
        relays = lib.optional (!isLighthouse) lighthouseIp;
        staticHostMap = { ${lighthouseIp} = cfg.lighthouseEndpoints; };
        # Lighthouse luistert vast op 4242 (de module zet de UDP-poort in de host-firewall
        # open); nodes kiezen een willekeurige poort.
        listen.port = if isLighthouse then 4242 else 0;
        settings.punchy = { punch = true; respond = true; };
        firewall = {
          outbound = [{ port = "any"; proto = "any"; host = "any"; }];
          inbound = [{ port = "any"; proto = "icmp"; host = "any"; }]
            ++ hosts.${host}.inbound;
        };
      };

      # De Nebula-firewall hierboven is de poortwachter voor de overlay; de host-firewall
      # vertrouwt de tun-interface zodat er geen tweede, afwijkende regelset ontstaat.
      networking.firewall.trustedInterfaces = [ "nebula.${netName}" ];
    })
  ]);
}
