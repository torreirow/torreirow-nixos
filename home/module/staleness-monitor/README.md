# staleness-monitor

Meldt via Signal wanneer periodiek werk **te lang niet is geslaagd**, in plaats van bij elke losse
mislukking.

```nix
services.staleness-monitor = {
  enable = true;
  checkTime = "20:00";
  watch.nextcloud = {
    stampFile = config.services.nextcloud-sync.stampFiles.docs;
    message   = "Nextcloud-sync op lobos is te lang niet gelukt";
    readinessCommand = ''
      curl -sS --fail --max-time 10 https://nxc.toorren.net/status.php \
        | jq -e '.installed == true and .maintenance == false' >/dev/null
    '';
  };
};
```

## Waarom dit bestaat

De Nextcloud-server (bobadela1) gaat 's nachts uit om stroom te besparen en wordt 's ochtends
handmatig gewekt. Een melding per mislukte sync gaf daardoor elke ochtend loos alarm. Gemeten op
2026-09-17:

```
22:24:55  ▼ lobos suspend
          │   23:00  bobadela1 uit — lobos slaapt, dus geen sync, geen melding
06:24:37  ▲ lobos wakker
06:24:37  ✗ sync faalt → Signal   "Host nxc.toorren.net not found"   (lobos zonder netwerk)
06:34:20  ✗ sync faalt → Signal   "502 Bad Gateway"                  (nginx leeft, backend niet)
06:42:44  ✓ sync geslaagd                                            (server gewekt)
```

Let op dat die twee mislukkingen verschillende oorzaken hadden. Oorzaken uit elkaar houden is duur;
de vraag *"is er de afgelopen 24 uur überhaupt gesynct?"* is dat niet. Deze module meet daarom het
**resultaat** en niet de storing — een laag minder machinerie dan een filter op oorzaken, niet meer.

## De twee drempels

```
  leeftijd van het laatste succes
  ──────────────────────────────────────────────────────────────►
   0                  softMaxAge (24u)          hardMaxAge (48u)
   │                       │                          │
   │   geen melding        │   melden ALS readiness   │   altijd melden
   │                       │   slaagt                 │
```

Waarom niet één drempel? Beide enkelvoudige varianten hebben een gat:

| Variant | Gat |
|---------|-----|
| Alleen ">24u → melden" | maandagochtend na een weekend weg meldt hij terecht maar overbodig, precies terwijl je de server al wekt |
| Alleen "melden als de server bereikbaar is" | vergeet je de server dagen te wekken, dan is hij op geen enkel controlemoment bereikbaar en hoor je nóóit iets |

De harde drempel dekt het tweede gat, de readiness-check het eerste. Laat je `readinessCommand`
weg, dan vallen beide drempels samen en heb je het eenvoudige gedrag.

## Het readiness-commando moet op inhoud toetsen

Niet op een statuscode, en al helemaal niet op een open poort:

- Er staat een **nginx vóór Nextcloud** die blijft antwoorden als de backend plat ligt — dan met
  **502**. Een TCP-connect op 443 zegt dus ten onrechte "beschikbaar".
- Een **captive portal** geeft vrolijk HTTP 200 met HTML terug.

Vandaar `--fail` (vangt de 502) plus `jq -e` op `installed` en `maintenance`: alleen een draaiende,
niet-onderhoudende Nextcloud telt.

## Waar "laatst geslaagd" vandaan komt

Nergens uit systemd — dat kent alleen de uitkomst van de láátste run. Daarom legt
`nextcloud-sync` het moment vast met `ExecStartPost=`, dat per definitie alleen draait ná een
geslaagde `ExecStart`. De **mtime** van dat bestand ís de state; er wordt niets geparseerd.

Het bestand wordt bij activatie aangemaakt als het nog niet bestaat. Zo is de betekenis eenduidig:
*"zo lang geleden is het voor het laatst gelukt, of anders zo lang geleden is de bewaking
ingesteld"*. Een verse installatie die nooit synct meldt zich dus na `hardMaxAge`.

## Handmatig draaien en testen

```bash
systemctl --user start staleness-monitor.service
journalctl --user -u staleness-monitor -n 20
systemctl --user list-timers staleness-monitor.timer
```

Om de drempels te testen zonder twee dagen te wachten, zet je de stempel terug:

```bash
ST=~/.local/state/nextcloud-sync/last-success-docs
touch -d '30 hours ago' "$ST"   # zacht venster
touch -d '60 hours ago' "$ST"   # voorbij de harde drempel
touch "$ST"                     # weer als nu
```

De vier takken zijn zo afzonderlijk te bevestigen; de journal vertelt per item welke tak het nam.

## Dit is géén dodemansknop

De monitor draait op **dezelfde machine** als het werk dat hij bewaakt. Valt lobos uit, dan draait
de check niet en komt er geen melding. Een echte dodemansknop vereist een heartbeat naar een
altijd-draaiende host (malandro, dat sowieso beter kan onderscheiden of het aan de server of aan
je laptop ligt). Bewust buiten scope.

## Bewust buiten scope

| Niet hier | Waarom |
|-----------|--------|
| Automatisch wekken van bobadela1 (wake-on-LAN) | regelt de gebruiker zelf; lost de probleemklasse eerder op dan dat het 'm stil maakt |
| Heartbeat naar malandro als echte dodemansknop | eigen change; zie hierboven |
| Staleness-bewaking op `remarkable-sync` | die tablet hangt er legitiem dagen niet aan — een ouderdomsalarm zou daar pure ruis zijn. Die module houdt juist zijn melding per mislukking, omdat afwezigheid daar al exit 0 geeft en een échte fout dus altijd iets betekent |

Het patroon generaliseert dus wel, het beleid niet. Daarom is bewaking opt-in per item.
