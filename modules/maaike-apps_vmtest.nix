# VM-test voor modules/maaike-apps.nix: seeds bij de eerste HM-activatie, een tweede activatie
# laat een gewijzigd bestand staan, herstel-app zet de standaard terug met een .bak-*.
#
#   nix build .#checks.x86_64-linux.maaike-apps -L
#
# Zonder spotifyPrefs (geen host-sleutel in de VM); dat pad dekt een eval-check op mpenzi.
{ ... }:

{
  name = "maaike-apps";

  nodes.machine = { ... }: {
    users.users.maaike = { isNormalUser = true; };
    toorren.maaike.enable = true;
    system.stateVersion = "26.05";
  };

  testScript = ''
    cfg = "/home/maaike/.config/Nextcloud/nextcloud.cfg"

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-maaike.service")

    with subtest("seeds na de eerste activatie"):
        machine.succeed(f"grep -qx '0\\\\url=https://nxc.toorren.net' {cfg}")
        machine.succeed(f"grep -qx '0\\\\dav_user=mtoorren' {cfg}")
        machine.succeed(f"test \"$(stat -c %U {cfg})\" = maaike")
        machine.succeed(f"test ! -L {cfg}")
        machine.succeed("grep -q 'https://vw.toorren.net' /home/maaike/.config/Bitwarden/data.json")
        machine.succeed("test -f /home/maaike/.config/ZapZap/ZapZap.conf")
        machine.succeed("grep -qx 'hwdec=auto' /home/maaike/.config/smplayer/smplayer.ini")
        machine.succeed("grep -qx 'RecordingDevice=podcast' /home/maaike/.config/audacity/audacity.cfg")
        machine.succeed("grep -qx 'RecordChannels=2' /home/maaike/.config/audacity/audacity.cfg")

    with subtest("tweede activatie overschrijft niets"):
        machine.succeed(f"su maaike -c 'echo eigen-keuze >> {cfg}'")
        machine.succeed("systemctl restart home-manager-maaike.service")
        machine.succeed(f"grep -qx eigen-keuze {cfg}")

    with subtest("herstel-app zet de standaard terug"):
        # Nep-app van maaike en een proces met dezelfde naam van root: alleen de eerste stopt.
        # Script zonder exec: de shell blijft draaien met /tmp/nextcloud in de cmdline.
        machine.succeed("printf '#!/bin/sh\\n%s 1000\\n' $(command -v sleep) > /tmp/nextcloud && chmod 755 /tmp/nextcloud")
        machine.succeed("systemd-run --uid=maaike --unit=nep-nextcloud /tmp/nextcloud")
        machine.succeed("systemd-run --unit=root-nextcloud /tmp/nextcloud")
        machine.wait_until_succeeds("pgrep -u maaike -f nextcloud", timeout=30)
        out = machine.succeed("herstel-app maaike nextcloud")
        assert "standaard neergezet" in out, out
        assert "nextcloud: gestopt" in out, out
        machine.fail("pgrep -u maaike -f nextcloud")
        machine.succeed("pgrep -u root -f /tmp/nextcloud")
        machine.fail(f"grep -qx eigen-keuze {cfg}")
        machine.succeed(f"grep -qx '0\\\\url=https://nxc.toorren.net' {cfg}")
        machine.succeed(f"grep -qx eigen-keuze {cfg}.bak-*")
        machine.succeed(f"test \"$(stat -c %U {cfg})\" = maaike")

    with subtest("onbekende app of gebruiker geeft een foutmelding"):
        status, out = machine.execute("herstel-app maaike foo 2>&1")
        assert status != 0 and "nextcloud" in out, out
        status, out = machine.execute("herstel-app iemand nextcloud 2>&1")
        assert status != 0 and "onbekende gebruiker" in out, out

    with subtest("signal en spotify zonder secret: alleen uitleg"):
        assert "QR-code" in machine.succeed("herstel-app maaike signal")
        machine.succeed("herstel-app maaike spotify 2>&1 | grep -q 'logt zelf in'")

    with subtest("herstel-app audacity"):
        machine.succeed("su maaike -c 'echo RecordChannels=1 > /home/maaike/.config/audacity/audacity.cfg'")
        machine.succeed("herstel-app maaike audacity")
        machine.succeed("grep -qx 'RecordChannels=2' /home/maaike/.config/audacity/audacity.cfg")
        machine.succeed("grep -qx 'RecordChannels=1' /home/maaike/.config/audacity/audacity.cfg.bak-*")

    with subtest("all"):
        machine.succeed("rm /home/maaike/.config/ZapZap/ZapZap.conf")
        machine.succeed("herstel-app maaike all")
        machine.succeed("test -f /home/maaike/.config/ZapZap/ZapZap.conf")
  '';
}
