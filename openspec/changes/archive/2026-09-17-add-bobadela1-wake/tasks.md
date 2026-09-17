## 1. Voorbereiding

- [x] 1.1 Bevestigen: bobadela1 MAC `b8:ac:6f:c7:20:c6`, IP `192.168.2.67`, broadcast `192.168.2.255`, WoL-poorten 7/9
- [x] 1.2 Bevestigen: Nextcloud status-endpoint `http://192.168.2.67:11000/status.php` geeft 200 + `installed:true`, `maintenance:false`
- [x] 1.3 Bevestigen: malandro (192.168.2.52) en bobadela1 in hetzelfde L2-broadcastdomein; uitgaand UDP-broadcast werkt zonder open firewall-poort
- [x] 1.4 Signal-constanten overnemen uit `modules/rustic-backup.nix` (api `127.0.0.1:8088/v2/send`, afzender `+31612652352`, ontvanger `+31636201589`)

## 2. Gedeelde wake-derivation

- [x] 2.1 Gedeeld script `modules/wake-bobadela1/wake-bobadela1.py` (pure Python stdlib, shebang `env python3`)
- [x] 2.2 WoL-kern uit het bestaande `~/bin/wake-bobadela1` overnemen (magic packet, ping-poll, re-burst)
- [x] 2.3 CLI-flags: `--wait` (default 0), `--burst` (default 300), `--check-nextcloud`, `--notify`, plus `--mac/--broadcast/--host`
- [x] 2.4 Nextcloud-health-check: poll `status.php` (volgt `--host`), gezond = HTTP 200 + `installed==true` + `maintenance==false`, binnen het venster
- [x] 2.5 Twee faal-modi met eigen exit + Signal-tekst: **A** geen ping (exit 1) / **B** ping-ok-NC-niet (exit 2)
- [x] 2.6 Signal-send helper via urllib (best-effort; faalt stil zodat de exitcode ongewijzigd blijft)

## 3. NixOS-module (malandro)

- [x] 3.1 `modules/wake-bobadela1/default.nix`; het script via `writeShellScriptBin`-wrapper (`python3 ${./…py}`, `iputils` op PATH → store-path, geen `/home`-dep)
- [x] 3.2 `systemd.services.wake-bobadela1` (oneshot): `--wait 1800 --burst 300 --check-nextcloud --notify`, `TimeoutStartSec=35min`, `after/wants network-online`
- [x] 3.3 `systemd.timers.wake-bobadela1`: `OnCalendar=*-*-* 09:00:00`, `Persistent=true`, `WantedBy=timers.target`
- [~] 3.4 `OnFailure=`-vangnet: niet nodig — het script vangt zelf alle faalpaden af en stuurt de specifieke Signal-melding; een generieke vangnet-notify zou alleen dubbelen
- [x] 3.5 Hardening: service draait als root (WoL-broadcast + status.php); geen extra firewall-poort geopend

## 4. Home-manager (~/bin)

- [x] 4.1 `home/module/wake-bobadela1/default.nix`: `home.file."bin/wake-bobadela1"` (`readFile` van dezelfde `.py`), geïmporteerd in `home/linux-server.nix`
- [x] 4.2 Los handgeplaatst `/home/wtoorren/bin/wake-bobadela1` verwijderd; HM-symlink neemt het over

## 5. Integratie & verificatie

- [x] 5.1 Module geïmporteerd in `hosts/malandro/configuration.nix`
- [x] 5.2 `sudo nixos-rebuild switch --flake .#malandro` slaagt zonder fouten
- [x] 5.3 `systemctl list-timers wake-bobadela1.timer` toont volgende run 2026-09-18 09:00, `Persistent=yes`
- [~] 5.4 Volledige cold-boot round-trip **niet forceren midden op de dag** (zou de live Nextcloud platleggen); wordt gedekt door de echte 09:00-run. Idempotent pad wél live geverifieerd via `systemctl start` → "al gezond", exit 0
- [x] 5.5 Faal-modus A getest (bogus host, kort `--wait`, zonder `--notify`) → exit 1, tekst "kwam niet op"
- [x] 5.6 Faal-modus B getest (host pingt, geen NC op :11000) → exit 2, tekst "Nextcloud reageert niet"
- [x] 5.7 Idempotentie: service starten terwijl bobadela1 gezond is → exit 0, geen packet
- [x] 5.8 Handmatig `wake-bobadela1` (PATH + `~/bin`-symlink) draait dezelfde logica; standaard zonder notify
- [~] Signal-verzending: niet live afgevuurd om geen ruis naar de familie te sturen; identiek patroon/API als het beproefde `rustic-notify@`. Eenmalig te bevestigen met `wake-bobadela1 --host <bogus> --wait 5 --notify`

## 6. Documentatie

- [x] 6.1 `hosts/bobadela1/README.md` bijgewerkt met de ochtend-wake (09:00, 30 min/5 min, NC-check, Signal)
- [x] 6.2 CHANGELOG bijgewerkt onder `## NEXT VERSION` (Added: bobadela1 ochtend-wake)
