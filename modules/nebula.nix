# Nebula-mesh "toorren": lighthouses (primair + backup) en nodes (zie docs/mpenzi.md).
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

  # Lighthouses in voorkeursorde. Nebula kent geen echte prioriteit — elke node vraagt
  # ze allemaal — maar hier staat de altijd-aan primaire (farol, EC2) vooraan en malandro
  # als backup. Valt farol weg, dan pakken nodes malandro.
  lighthouses = [ "farol" "malandro" ];

  # Eén relay voor nodes die achter NAT/CGNAT geen directe tunnel krijgen. Bewust niet
  # elke lighthouse: relayen kost egress (op EC2 $0,09/GB).
  relayHost = "malandro";

  # IP per host plus de extra inbound-regels bovenop ICMP en ssh (die gelden op elke host,
  # zie `firewall.inbound`). Nebula-firewall matcht op de naam in het certificaat (`host`),
  # dus `nebula-cert sign -name lobos` is hier lobos. `endpoints` zijn de underlay-adressen
  # waarop andere hosts een lighthouse bereiken; alleen lighthouses hebben die nodig.
  hosts = {
    malandro = {
      ip = "10.77.0.1";
      # LAN eerst (thuis, geen NAT-hairpin nodig), daarna het publieke adres.
      endpoints = [ "192.168.2.52:4242" "wg.toorren.net:4242" ];
      inbound = [ ];
    };
    lobos = {
      ip = "10.77.0.2";
      inbound = [
        { port = 3003; proto = "tcp"; host = "malandro"; } # Immich-ML (modules/immich-ml.nix)
      ];
    };
    mpenzi = {
      ip = "10.77.0.3";
      inbound = [
        { port = 21118; proto = "tcp"; host = "lobos"; }   # RustDesk direct IP
      ];
    };
    farol = {
      # AWS EC2 (eu-central-1, t3a.nano); altijd-aan lighthouse. Komt in `lighthouses`
      # zodra het certificaat er is.
      ip = "10.77.0.4";
      endpoints = [ "farol.toorren.net:4242" ];
      inbound = [ ];
    };
  };

  isLighthouse = builtins.elem host lighthouses;
  isRelay = host == relayHost;

  # De andere lighthouses: nodes vragen hen naar hosts, en dit is de static_host_map
  # waarmee elke host ze kan bereiken (een naam mag, Nebula resolvet hem periodiek).
  otherLighthouses = builtins.filter (n: n != host) lighthouses;
  lighthouseIps = map (n: cfg.hosts.${n}.ip) otherLighthouses;
  # Endpoints per lighthouse: de tabel hierboven is de default, deze optie kan ze per
  # host overschrijven (de VM-test doet dat, want daar is het adres dynamisch).
  endpointsOf = n:
    if cfg.lighthouseEndpoints ? ${n} then cfg.lighthouseEndpoints.${n}
    else cfg.hosts.${n}.endpoints;
  lighthouseMap = lib.listToAttrs (map
    (n: lib.nameValuePair cfg.hosts.${n}.ip (endpointsOf n))
    (builtins.filter (n: endpointsOf n != [ ]) otherLighthouses));
  relayIp = cfg.hosts.${relayHost}.ip;

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

    # De tabel staat hier zodat andere modules (de statuspagina op malandro) niet
    # een tweede kopie van de IP's hoeft bij te houden. `internal` houdt hem uit
    # de documentatie; de waarden zijn gewoon leesbaar via `config`.
    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          ip = lib.mkOption { type = lib.types.str; };
          endpoints = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Underlay-adressen (host:poort) waarop deze lighthouse bereikbaar is.";
          };
          inbound = lib.mkOption {
            type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
            default = [ ];
          };
        };
      });
      default = hosts;
      internal = true;
      description = "Hosts in de mesh met hun Nebula-IP, lighthouse-endpoints en inbound-regels.";
    };

    # Alleen-lezen spiegels van de let-bindings hierboven, voor de rol-kolom op de
    # statuspagina. Aanpassen gebeurt in het let-blok, niet via deze opties.
    lighthouses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lighthouses;
      readOnly = true;
      internal = true;
    };

    relayHost = lib.mkOption {
      type = lib.types.str;
      default = relayHost;
      readOnly = true;
      internal = true;
    };

    lighthouseEndpoints = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Per lighthouse (hostnaam) de underlay-adressen waarop hij bereikbaar is.
        Overschrijft de `endpoints` uit de hosts-tabel; bedoeld voor tests en
        omgevingen waar het adres niet vaststaat.
      '';
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
      assertions = [
        {
          assertion = cfg.hosts ? ${host};
          message = "toorren.nebula: host '${host}' staat niet in de hosts-tabel van modules/nebula.nix.";
        }
        {
          assertion = lib.all (n: cfg.hosts ? ${n} && endpointsOf n != [ ]) lighthouses;
          message = "toorren.nebula: elke lighthouse in `lighthouses` moet in de hosts-tabel staan met een niet-lege `endpoints`-lijst.";
        }
      ];
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
        inherit isLighthouse isRelay;
        # Elke host vraagt alle lighthouses (behalve zichzelf) en kan ze via de
        # static_host_map bereiken; `relays` is één host, zodat nodes achter CGNAT
        # niet van elke lighthouse een relay maken.
        lighthouses = lighthouseIps;
        relays = lib.optional (!isRelay) relayIp;
        staticHostMap = lighthouseMap;
        # Alle hosts luisteren vast op 4242. Met een willekeurige poort (0) hield de host-firewall
        # van de nodes de eerste pakketten tegen, waardoor lobos en mpenzi zelfs op hetzelfde LAN
        # pas na 5-8 s via de relay verbonden (gemeten 2026-11-04). Achter CGNAT (5G) blijft de
        # relay nodig; dat lost een vaste poort niet op.
        listen.port = 4242;
        settings.punchy = { punch = true; respond = true; };
        firewall = {
          outbound = [{ port = "any"; proto = "any"; host = "any"; }];
          # ICMP en ssh staan op elke host open voor de hele mesh, voor beheer over en weer.
          inbound = [
            { port = "any"; proto = "icmp"; host = "any"; }
            { port = 22; proto = "tcp"; host = "any"; }
          ] ++ cfg.hosts.${host}.inbound;
        };
      };

      # De Nebula-firewall hierboven is de poortwachter voor de overlay; de host-firewall
      # vertrouwt de tun-interface zodat er geen tweede, afwijkende regelset ontstaat.
      networking.firewall.trustedInterfaces = [ "nebula.${netName}" ];
      # NetworkManager liet de tun-interface "disconnected" staan en haalde er het adres
      # van af (lobos, 2026-11-12): de service draaide door, maar zonder IP/route geen mesh.
      # Nebula beheert zijn eigen adres; NM blijft eraf. mkIf: malandro/farol hebben geen NM.
      networking.networkmanager.unmanaged =
        lib.mkIf config.networking.networkmanager.enable [ "interface-name:nebula.*" ];
      # Underlay-poort open op elke host (de nixpkgs-module doet dat niet zelf). Nebula neemt
      # alleen handshakes met een certificaat van de eigen CA aan.
      networking.firewall.allowedUDPPorts = [ 4242 ];
    })
  ]);
}
