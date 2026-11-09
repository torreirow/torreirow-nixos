# Podcast opnemen met twee USB-microfoons, elk op een eigen spoor (mpenzi, 2x NZXT Capsule).
#
#   toorren.podcast = { enable = true; mic1Path = "pci-..."; mic2Path = "pci-..."; };
#
# - Vaste namen per USB-poort (udev ID_PATH): beide Capsules hebben hetzelfde serienummer, dus
#   alleen de poort onderscheidt ze. Bron "Podcast mic 1"/"2", node.name podcast-mic-1/-2.
# - Route B: virtuele stereobron "Podcast (2 mics)" (links mic 1, rechts mic 2), in Audacity
#   te kiezen als ALSA-apparaat `podcast`.
# - Route A: `podrec start|stop` (ook in het menu) schrijft mic1.flac en mic2.flac.
#
# Zie docs/podcast-mpenzi.md, OpenSpec podcast-recording.
{ config, lib, pkgs, ... }:

let
  cfg = config.toorren.podcast;
  podrec = pkgs.callPackage ./package.nix { };
  mics = [
    { n = "1"; path = cfg.mic1Path; channel = "FL"; }
    { n = "2"; path = cfg.mic2Path; channel = "FR"; }
  ];
in
{
  options.toorren.podcast = {
    enable = lib.mkEnableOption "podcastopname met twee USB-microfoons";

    mic1Path = lib.mkOption {
      type = lib.types.str;
      example = "pci-0000:04:00.3-usb-0:2:1.0";
      description = "udev ID_PATH van de USB-poort voor Podcast mic 1 (linkerkanaal).";
    };

    mic2Path = lib.mkOption {
      type = lib.types.str;
      example = "pci-0000:04:00.4-usb-0:2:1.0";
      description = "udev ID_PATH van de USB-poort voor Podcast mic 2 (rechterkanaal).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.services.pipewire.enable && config.services.pipewire.alsa.enable;
      message = "toorren.podcast vraagt services.pipewire met alsa.enable.";
    }];

    # Twee stappen: het apparaat krijgt een vaste device.name, waar WirePlumber de nodenaam
    # (alsa_input.podcast-mic-N.<profiel>) van afleidt; die node krijgt daarna de korte naam.
    services.pipewire.wireplumber.extraConfig."60-podcast" = {
      "monitor.alsa.rules" = lib.concatMap (m: [
        {
          matches = [{ "device.bus-path" = m.path; }];
          actions.update-props = {
            "device.name" = "alsa_card.podcast-mic-${m.n}";
            "device.description" = "Podcast mic ${m.n}";
          };
        }
        {
          matches = [{ "node.name" = "~alsa_input\\.podcast-mic-${m.n}\\..*"; }];
          actions.update-props = {
            "node.name" = "podcast-mic-${m.n}";
            "node.description" = "Podcast mic ${m.n}";
            "node.nick" = "Podcast mic ${m.n}";
            # Nooit vanzelf de standaardmicrofoon (Zoom/Jitsi blijven op de laptop-mic).
            "priority.session" = 100;
          };
        }
        {
          # De koptelefoonuitgang van de Capsule: nooit vanzelf de standaard-uitvoer, anders
          # verdwijnt al het laptopgeluid naar de microfoon.
          matches = [{ "node.name" = "~alsa_output\\.podcast-mic-${m.n}\\..*"; }];
          actions.update-props = {
            "node.description" = "Podcast mic ${m.n} koptelefoon";
            "priority.session" = 100;
          };
        }
      ]) mics;
    };

    # Route B. De streams hangen aan de gewone mic-nodes, dus hun Plasma-schuif regelt het volume.
    services.pipewire.extraConfig.pipewire."60-podcast" = {
      "context.modules" = [{
        name = "libpipewire-module-combine-stream";
        args = {
          "combine.mode" = "source";
          "node.name" = "podcast-2mics";
          "node.description" = "Podcast (2 mics)";
          "combine.latency-compensate" = false;
          "combine.props"."audio.position" = [ "FL" "FR" ];
          "stream.props" = { };
          "stream.rules" = map (m: {
            matches = [{ "media.class" = "Audio/Source"; "node.name" = "podcast-mic-${m.n}"; }];
            actions.create-stream = {
              "audio.position" = [ "MONO" ];
              "combine.audio.position" = [ m.channel ];
            };
          }) mics;
        };
      }];
    };

    # Audacity (PortAudio/ALSA) ziet PipeWire-nodes niet los; dit benoemde apparaat wel.
    environment.etc."alsa/conf.d/60-podcast.conf".text = ''
      pcm.podcast {
        type pipewire
        capture_node "podcast-2mics"
        hint {
          show on
          description "Podcast (2 mics)"
        }
      }
    '';

    environment.systemPackages = [ podrec ];
  };
}
