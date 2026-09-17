## Why

bobadela1 (Nextcloud AIO op JuiceFS/S3) gaat elke avond 23:00 netjes uit via `nightly-shutdown`
(zwakke accu; koude start werkt betrouwbaarder dan een warme reboot). De **wake-kant is nu handwerk**:
uit de boot-historie blijkt dat de machine op wisselende tijden opkomt (15 sep 21:05, 16 sep 08:28,
17 sep 06:35) — er is geen RTC-alarm, geen cron, geen service die hem 's ochtends aanzet. Wie 's ochtends
Nextcloud nodig heeft, moet bobadela1 eerst met de hand wekken.

Het bestaande script `/home/wtoorren/bin/wake-bobadela1` (Wake-on-LAN + ping-poll + re-burst) doet het
wakker maken al, maar staat als **los, handgeplaatst bestand** buiten nix (de andere `~/bin`-scripts zijn
home-manager-symlinks) en er is geen automatisering, geen 30-minuten-doorzettingslogica, geen
Nextcloud-gezondheidscheck en geen melding als het misgaat.

## What Changes

- Nieuwe gedeelde nix-derivation met de wake-logica (`writers.writePython3Bin`), afgeleid van het huidige
  script en uitgebreid met: Nextcloud-health-check en Signal-notificatie.
- Nieuwe NixOS-module `modules/wake-bobadela1.nix` (geïmporteerd in `hosts/malandro/configuration.nix`):
  - `wake-bobadela1.service` (oneshot, root) die de wake-derivation draait in service-modus.
  - `wake-bobadela1.timer` — `OnCalendar=*-*-* 09:00`, **dagelijks inclusief weekend**, `Persistent=true`.
- **Retry-gedrag:** de service probeert **30 minuten** lang, met een WoL-burst **elke 5 minuten** (6 bursts),
  en pollt tussendoor de bereikbaarheid.
- **Succescriterium = Nextcloud, niet alleen ping:** de service is pas klaar als
  `http://192.168.2.67:11000/status.php` HTTP 200 geeft met `"installed":true` en `"maintenance":false`.
- **Twee onderscheiden faal-modi met eigen Signal-tekst:**
  - **A** — geen ping binnen 30 min → "bobadela1 kwam niet op na 30 min WoL".
  - **B** — pingt wél, maar Nextcloud werd niet gezond binnen het venster → "bobadela1 is op maar
    Nextcloud reageert niet (status.php)".
- Signal-melding via de bestaande lokale signal-cli REST API (`http://127.0.0.1:8088/v2/send`), zelfde
  afzender/ontvanger als `rustic-notify@` en HA `signal_maria`.
- De home-manager `~/bin`-versie van `wake-bobadela1` wordt de **beheerde symlink** naar dezelfde
  derivation (los handgeplaatst bestand verdwijnt), zodat handmatig wekken blijft werken vanuit één bron.

## Capabilities

### New Capabilities
- `bobadela1-wake`: Een geautomatiseerde, doorzettende Wake-on-LAN-wekker op malandro die bobadela1 elke
  ochtend 09:00 aanzet, 30 minuten lang blijft proberen (WoL-burst elke 5 min), pas tevreden is als
  Nextcloud daadwerkelijk gezond antwoordt, en bij falen een onderscheidende Signal-melding stuurt.

### Modified Capabilities
<!-- Geen bestaande capability-requirements wijzigen. -->

## Impact

- **Nieuw bestand:** `modules/wake-bobadela1.nix` (module + gedeelde wake-derivation + timer/service +
  Signal-notify).
- **Gewijzigd:** `hosts/malandro/configuration.nix` (import), home-manager-config van wtoorren (script als
  `home.file`/module-symlink naar `~/bin/wake-bobadela1` i.p.v. los bestand).
- **Runtime:** de service draait als root op malandro (192.168.2.52) en verstuurt UDP-broadcast naar
  192.168.2.255:7,9. Uitgaand broadcast vereist geen extra capabilities en geen open firewall-poort.
- **Afhankelijkheden:** Python 3 (aanwezig), `iputils`/`ping`, `curl`. Geen nieuwe externe services;
  signal-cli REST API draait al (poort 8088).
- **Samenhang:** vormt het ochtend-complement van het bestaande `nightly-shutdown` (23:00) op bobadela1;
  buiten ~06:30–23:00 kan er sowieso niet gesynct worden omdat de host uit staat.
- **Geen geheimen:** telefoonnummers staan (net als in `rustic-backup.nix`) plain in de module; er is geen
  agenix-secret nodig.
