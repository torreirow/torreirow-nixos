## Why

De per-mislukking-melding op `nextcloud-sync` levert structureel loos alarm. De Nextcloud-server
(bobadela1) gaat om 23:00 uit om stroom te besparen en wordt 's ochtends handmatig gewekt. Gemeten
op 2026-09-17: lobos sliep van 22:24 tot 06:24, werd wakker, en faalde twee keer vóór de server om
06:42 beschikbaar was — twee Signal-berichten voor geplande downtime.

Die twee mislukkingen hadden bovendien verschillende oorzaken (`Host not found` = lobos had zelf
nog geen netwerk; `502 Bad Gateway` = nginx leeft maar Nextcloud niet), wat een oorzaak-gebaseerde
filter duur maakt.

Het onderliggende probleem is de gekozen meeteenheid. Een individuele mislukte run zegt weinig:
hij mislukt óók als alles in orde is maar de server nog slaapt. Wat er werkelijk toe doet is of er
de afgelopen periode überhaupt gesynct is. Die vraag laat zich beantwoorden zonder de oorzaak te
kennen, en maakt de storingsdetectie daarmee eenvoudiger in plaats van ingewikkelder.

## What Changes

- **Nieuwe home-manager-module `home/module/staleness-monitor/`** die per watch-item bewaakt of een
  stempelbestand recent genoeg is bijgewerkt, en anders een melding stuurt via de bestaande
  `notify-signal@`-unit.
- **Twee drempels per item** (de afgewogen variant, zie design):
  - `softMaxAge` (24u) — melden zodra een optionele `readinessCommand` slaagt, zodat er nooit
    alarm afgaat in het ochtendgat waarin de server nog uit is;
  - `hardMaxAge` (48u) — melden ongeacht readiness, zodat een server die dagen uit blijft alsnog
    een herinnering oplevert.
  Zonder `readinessCommand` vallen beide drempels samen en is het gedrag een kale staleness-check.
- **`nextcloud-sync` legt een succesmoment vast** via `ExecStartPost=` (systemd draait dat alleen
  na een geslaagde `ExecStart`), in `~/.local/state/nextcloud-sync/last-success-<naam>`.
- **De per-mislukking-melding op `nextcloud-sync` vervalt** (`onFailure` leeg). De staleness-check
  neemt die rol over.
- **De inerte netwerk-afhankelijkheid verdwijnt**: `After`/`Wants=network-online.target` staat in de
  unit, maar die target heeft in de user-manager `LoadState=not-found` en doet dus niets.
- **`remarkable-sync` houdt zijn per-mislukking-melding.** Die module heeft al een probe waardoor
  een afwezig apparaat exit 0 geeft; een echte faalmelding betekent daar dus altijd iets. Een
  staleness-alarm zou daar juist ruis zijn, want de tablet hangt er legitiem dagen niet aan.

## Capabilities

### New Capabilities

- `sync-staleness-monitor`: Bewaakt of periodiek werk recent genoeg is geslaagd en meldt het
  uitblijven daarvan, in plaats van elke losse mislukking.

### Modified Capabilities

- `nextcloud-sync`: legt na een geslaagde sync een succesmoment vast dat door de staleness-monitor
  gelezen kan worden, en draagt de faalmelding over aan die monitor.
- `service-failure-notifications`: het meldkanaal wordt herbruikbaar voor meldingen die géén
  unit-fout zijn. De verzender (token lezen + versturen) wordt losgetrokken van het opbouwen van de
  faaltekst, zodat de staleness-monitor zijn eigen bericht kan sturen zonder een tweede token-lezing
  of een tweede curl-implementatie.

## Impact

- **Host:** alleen `lobos`, via home-manager.
- **Nieuw:** `home/module/staleness-monitor/` (module + timer + service), een import in `flake.nix`,
  en het stempelbestand onder `~/.local/state/nextcloud-sync/`.
- **Gewijzigd:** `home/module/nextcloud-sync/default.nix` (stempel, dode netwerk-afhankelijkheid
  eruit), `home/linux-desktop.nix` (`onFailure` weg bij nextcloud-sync, watch-item erbij),
  `CHANGELOG.md`.
- **Trade-off — reactietijd:** een storing om 10:00 wordt pas bij de eerstvolgende dagcheck gemeld
  in plaats van binnen tien minuten. Bewust geaccepteerd: het sync-volume is klein en een dag
  vertraging weegt niet op tegen dagelijks vals alarm.
- **Blinde vlek:** valt lobos zelf uit, dan draait de check niet en komt er geen melding. Een echte
  dodemansknop vereist een heartbeat naar een altijd-draaiende host (malandro). Buiten scope.
- **Buiten scope:** het automatisch wekken van bobadela1 (doet de gebruiker zelf), en een
  staleness-alarm op `remarkable-sync`.
