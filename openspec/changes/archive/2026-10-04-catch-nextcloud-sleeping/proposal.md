## Why

`bobadela1` (Nextcloud AIO, upstream `http://192.168.2.67:11000`) gaat elke avond 23:00 bewust uit
en wordt 09:00 door `wake-bobadela1` gewekt. Tussendoor kan de nginx-reverse-proxy op malandro
(`https://nxc.toorren.net`, `modules/nextcloud-proxy.nix`) de upstream niet bereiken.

Twee problemen vandaag:

1. **De bezoeker hangt.** De location zet `proxy_connect_timeout 3600s`. Staat de host uit, dan
   krijgt de TCP-SYN geen antwoord en blijft de connect-fase tot **een uur** openstaan vóór nginx
   een 504 geeft. Die 3600s is een copy-paste van de upload-timeouts; voor de *TCP-handshake* is
   het zinloos lang.
2. **De fout is lelijk.** Wanneer nginx wél faalt (504 bij uit, 502 bij host-aan-maar-container-niet-
   klaar) ziet de bezoeker de kale nginx-foutpagina, zonder uitleg dat dit verwacht nachtelijk
   gedrag is.

## What Changes

- **Snel falen:** `proxy_connect_timeout` op de nxc-location van 3600s → **3s**. De
  `proxy_send_timeout`/`proxy_read_timeout` (3600s, voor grote uploads) blijven ongewijzigd —
  die gelden voor de transfer-fase, niet de handshake.
- **Vriendelijke afvang:** `error_page 502 503 504 =503 @sleeping;` op de nxc-location + een nieuwe
  `internal` named location `@sleeping` die een statische pagina serveert met status **503 Service
  Unavailable** en een `Retry-After`-header.
- **Tijdbewuste pagina:** statische HTML (stijl van de bestaande `/errors/`-pagina's), met een
  client-side JS-klok: binnen 23:00–09:00 → "Nextcloud slaapt, terug om 09:00"; daarbuiten →
  "Nextcloud is onverwacht onbereikbaar".

## Non-goals

- **Geen "wek nu"-knop.** Wekken blijft de 09:00-timer (`wake-bobadela1`) + handmatige CLI.
- **Geen globale error_page-wijziging.** De afvang blijft gescoped op de nxc-vhost; andere vhosts
  (Paperless, Grafana, …) houden hun eigen 502-gedrag.
- **Geen `proxy_intercept_errors`.** Niet nodig: een connect-fout wordt door nginx zelf gegenereerd
  en door `error_page` afgevangen; die directive geldt alleen voor foutcodes die de upstream
  teruggeeft.
- **Geen server-side bepaling van het slaapvenster.** De venster-logica zit in client-side JS
  (browser-tijd); puur cosmetisch welke tekst verschijnt.

## Capabilities

### Added Capabilities

- `nextcloud-proxy`: de reverse-proxy naar Nextcloud faalt snel bij een onbereikbare upstream en
  serveert een tijdbewuste onderhoudspagina (503) in plaats van de kale nginx-fout.

## Impact

- `modules/nextcloud-proxy.nix` — connect-timeout omlaag, `error_page` + `@sleeping`-location,
  statische pagina via `environment.etc` + `systemd.tmpfiles` symlink naar `/var/www/nxc`.
- `openspec/specs/nextcloud-proxy/spec.md` — nieuwe capability (bij archivering aangemaakt via delta).
- Geen nieuwe secrets; geen wijziging aan de upload-timeouts of aan andere vhosts.
