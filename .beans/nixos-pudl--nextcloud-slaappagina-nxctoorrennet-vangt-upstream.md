---
# nixos-pudl
title: 'Nextcloud slaappagina: nxc.toorren.net vangt upstream-down netjes af'
status: completed
type: epic
priority: normal
created_at: 2026-10-04T20:57:57Z
updated_at: 2026-10-04T21:13:54Z
---

# Nextcloud slaappagina

bobadela1 (Nextcloud AIO, 192.168.2.67:11000) gaat elke avond 23:00 automatisch
uit en wordt 09:00 door `wake-bobadela1` gewekt. Tussendoor kan nginx op malandro
de upstream niet bereiken en toont de kale 502/504-foutmelding op
`https://nxc.toorren.net`.

## Doel

De upstream-down op **alleen** de nxc-vhost netjes afvangen met een vriendelijke,
tijdbewuste pagina, en zorgen dat die pagina snel verschijnt i.p.v. tot een uur
te hangen.

## Twee faalmodi

| Toestand bobadela1              | nginx geeft         | snelheid                       |
|---------------------------------|---------------------|--------------------------------|
| Uit (nachtelijke shutdown)      | 504 Gateway Timeout | pas na proxy_connect_timeout   |
| Aan, container nog niet klaar   | 502 Bad Gateway     | direct (connection refused)    |

## Scope (bevestigd met user)

- **Tijdbewuste pagina** (client-side JS-klok): 23:00-09:00 -> "slaapt, terug om
  09:00", anders -> "onverwacht onbereikbaar".
- **Connect-timeout verkorten** naar ~3s; send/read-timeouts (3600s, grote uploads)
  blijven staan. proxy_connect_timeout is enkel de TCP-handshake, niet de upload.
- **Wek-knop buiten scope** (wake blijft de 09:00-timer + handmatige CLI).

## Valkuilen

- `error_page 502/503/504` **scoped op de vhost**, niet in commonHttpConfig -- anders
  krijgt een echte 502 van Paperless/Grafana ook de "Nextcloud slaapt"-pagina.
- `proxy_intercept_errors` is hier **niet** nodig: een connect-fout genereert nginx
  zelf; error_page vangt dat direct. Die directive is alleen voor upstream-foutcodes.
- JS-klok draait in de browser van de bezoeker -> lokale apparaattijd, puur cosmetisch.

Volgt het OpenSpec-patroon: change `catch-nextcloud-sleeping`.



## Summary of Changes
Epic afgerond. `modules/nextcloud-proxy.nix`: snelle connect-timeout (3s) + `error_page 502 503 504 =503 @sleeping` + interne @sleeping-location die een tijdbewuste onderhoudspagina als HTTP 503 serveert (Retry-After, no-store), gescoped op alleen nxc. Static HTML via environment.etc + tmpfiles-symlink. OpenSpec-change catch-nextcloud-sleeping gemaakt, geimplementeerd, functioneel getest en gearchiveerd; capability-spec nextcloud-proxy toegevoegd. Alle 5 child-beans completed. Live uitgerold (generatie 72) en in productie geverifieerd: bij een echt uitgeschakelde bobadela1 geeft nxc.toorren.net binnen ~3s een 503 met de slaappagina (retry-after + no-store).
