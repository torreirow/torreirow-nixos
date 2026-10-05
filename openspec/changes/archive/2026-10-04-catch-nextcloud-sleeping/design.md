## Context

`modules/nextcloud-proxy.nix` proxyt `nxc.toorren.net` naar `http://192.168.2.67:11000` op
bobadela1. De host is tussen 23:00 en 09:00 bewust uit. De bestaande static-error-infrastructuur
in `modules/nginx.nix` (`environment.etc."nginx-errors/*"` + tmpfiles-symlinks naar `/var/www/errors`,
plus een `internal` location) is het patroon dat we hier spiegelen.

## De twee faalmodi (gemeten gedrag)

| Toestand bobadela1               | TCP-gedrag                  | nginx genereert     | timing                        |
|----------------------------------|-----------------------------|---------------------|-------------------------------|
| Uit (nachtelijke shutdown)       | SYN zonder antwoord         | 504 Gateway Timeout | pas na `proxy_connect_timeout`|
| Aan, container nog niet klaar    | RST / connection refused    | 502 Bad Gateway     | direct                        |

Beide codes worden door nginx **zelf** opgewekt (de upstream antwoordt niet), dus `error_page` vangt
ze zonder `proxy_intercept_errors`. We nemen ook 503 mee voor het geval de upstream straks zelf een
onderhoud-503 teruggeeft.

## Beslissingen

### 1. `proxy_connect_timeout` 3600s → 3s (upload-timeouts blijven)

`proxy_connect_timeout` begrenst alléén de TCP-handshake. Een gezonde host op het LAN maakt die in
milliseconden; 3s is ruim. De 3600s stond er omdat het naast `proxy_send_timeout`/`proxy_read_timeout`
is gekopieerd — maar die twee begrenzen de *transfer* (grote Nextcloud-uploads) en blijven 3600s.
Gevolg: bij een uitgeschakelde host valt de proxy binnen ~3s terug op de slaappagina in plaats van
tot een uur te hangen; grote uploads merken niets.

### 2. Afvang gescoped op de nxc-vhost, niet globaal

`error_page 502 503 504` komt in de `location "/"` van de nxc-vhost, niet in `commonHttpConfig`
(`modules/nginx.nix`). Anders zou een echte 502 van bv. Paperless of Grafana óók de
"Nextcloud slaapt"-pagina tonen. De `@sleeping`-location is `internal`, dus niet direct opvraagbaar.

### 3. Status 503 Service Unavailable + Retry-After (niet 200, niet de ruwe 502/504)

`error_page 502 503 504 =503 @sleeping;` herschrijft naar **503**. Overwegingen:

- **Sync-clients** (Nextcloud desktop/mobiel) die tijdens de nacht pollen krijgen zo een correct
  "tijdelijk niet beschikbaar"-signaal en backen af. Een `=` (status 200) met HTML-body zou een
  client misleiden alsof het een geldig antwoord kreeg.
- **Browsers** renderen de HTML-body van een 503 gewoon → bezoeker ziet de vriendelijke pagina.
- Een vaste `Retry-After: 1800` (30 min) is een redelijke hint; het exacte aantal seconden tot 09:00
  dynamisch berekenen kan niet triviaal in statische nginx-config en voegt weinig toe.

### 4. Tijdbewuste tekst in client-side JS

De pagina is één statisch bestand. Een klein stukje JS leest de lokale klok van de bezoeker:
23:00–09:00 → "slaapt, terug om 09:00"; daarbuiten → "onverwacht onbereikbaar". Dit draait in de
browser van de bezoeker (apparaattijd, niet malandro), maar is puur cosmetisch — welke code nginx
teruggeeft (503) hangt er niet van af. Geen backend-logica, geen extra endpoint.

### 5. Levering van de statische pagina

Zelfde mechaniek als `modules/nginx.nix`: `environment.etc."nginx-nxc/sleeping.html"` met de HTML,
plus `systemd.tmpfiles.rules` die `/var/www/nxc/sleeping.html` als symlink neerzet, en de
`@sleeping`-location met `root /var/www/nxc;` + `internal;`.

## Alternatieven afgewogen

- **`proxy_intercept_errors on`** — overbodig voor connect-fouten (nginx-eigen), alleen nodig voor
  upstream-geleverde foutcodes. Weggelaten.
- **Globale error_page voor 502/504** — verworpen: zou andere diensten verkeerd labelen.
- **Status 200 op de pagina** — verworpen: misleidt sync-clients.
- **Server-side slaapvenster-check / "wek nu"-knop** — buiten scope (zie proposal Non-goals).
