# VM-test voor modules/podcast-opname: twee snd-aloop-kaarten staan in voor de twee Capsules, een
# derde voor de laptop-geluidskaart
# (poortpaden platform-snd_aloop.0/.1). Een ingelogde gebruiker op tty1 draait PipeWire.
#
#   nix build .#checks.x86_64-linux.podcast-opname -L
#
# Toetst de pijplijn (namen, stereobron, ALSA-apparaat, podrec) met stilte. Een toon via aloop
# laat PipeWire in de VM vastlopen; links/rechts toetst test.nix (splitsen) en live op mpenzi.
{ ... }:

{
  name = "podcast-opname";

  nodes.machine = { pkgs, ... }: {
    imports = [ ./default.nix ];

    boot.kernelModules = [ "snd-aloop" ];
    boot.extraModprobeConfig = "options snd-aloop enable=1,1,1 index=0,1,2";

    services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
    security.rtkit.enable = true;

    users.users.alice = { isNormalUser = true; uid = 1000; extraGroups = [ "audio" ]; };
    # Actieve sessie op seat0, zoals Maaike in Plasma: WirePlumber neemt dan de kaarten.
    services.getty.autologinUser = "alice";

    toorren.podcast = {
      enable = true;
      mic1Path = "platform-snd_aloop.0";
      mic2Path = "platform-snd_aloop.1";
    };

    environment.systemPackages = with pkgs; [ alsa-utils sox jq pulseaudio ];
    system.stateVersion = "26.05";
  };

  testScript = ''
    def alice(cmd):
        return machine.succeed(f"su - alice -c 'XDG_RUNTIME_DIR=/run/user/1000 {cmd}'")

    def nodes():
        return alice("pw-dump | jq -r \".[].info.props[\\\"node.name\\\"]? // empty\"")

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    print(machine.succeed("udevadm info -q property /dev/snd/controlC0 /dev/snd/controlC1 | grep ID_PATH="))

    with subtest("bronnen per poort heten Podcast mic 1 en 2"):
        machine.wait_until_succeeds(
            "su - alice -c 'XDG_RUNTIME_DIR=/run/user/1000 pw-dump' | grep -q '\"podcast-mic-2\"'",
            timeout=90)
        n = nodes()
        print(n)
        assert "podcast-mic-1" in n.split() and "podcast-mic-2" in n.split(), n
        assert "Podcast mic 1" in alice("pactl list sources")

    with subtest("Capsules worden niet vanzelf standaard in- of uitvoer"):
        src = alice("pactl get-default-source").strip()
        sink = alice("pactl get-default-sink").strip()
        print(src, sink)
        assert "podcast" not in src and "podcast" not in sink, (src, sink)

    with subtest("stereobron Podcast (2 mics) met twee kanalen"):
        assert "podcast-2mics" in nodes().split()
        alice("arecord -L | grep -qx podcast")
        alice("arecord -D podcast -f S16_LE -c 2 -r 48000 -d 2 /tmp/b.wav")
        assert alice("soxi -c /tmp/b.wav").strip() == "2"

    with subtest("podrec: twee even lange mono-FLAC-sporen"):
        alice("podrec start")
        machine.sleep(5)
        alice("podrec stop")
        d = alice("ls -d /home/alice/Podcast/*").strip()
        print(alice(f"ls -A {d}"))
        assert alice(f"soxi -c {d}/mic1.flac").strip() == "1"
        assert alice(f"soxi -s {d}/mic1.flac") == alice(f"soxi -s {d}/mic2.flac")
        assert float(alice(f"soxi -D {d}/mic1.flac")) > 3

    with subtest("podrec weigert zonder mic 2"):
        alice("pactl set-card-profile alsa_card.podcast-mic-2 off")
        machine.wait_until_fails(
            "su - alice -c 'XDG_RUNTIME_DIR=/run/user/1000 pw-dump' | grep -q '\"podcast-mic-2\"'",
            timeout=60)
        status, out = machine.execute("su - alice -c 'XDG_RUNTIME_DIR=/run/user/1000 podrec start' 2>&1")
        assert status != 0 and "Podcast mic 2 niet gevonden" in out, out
  '';
}
