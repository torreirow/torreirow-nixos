## MODIFIED Requirements

### Requirement: Correcte nextcloudcmd-invocatie
Het systeem SHALL `nextcloudcmd` aanroepen als `[opties] <lokale_map> <server_url>`,
waarbij een leidende `~/` in paden geëxpandeerd wordt naar de home-dir en een
niet-root `remotePath` als `--path` wordt meegegeven. Het systeem SHALL GEEN
`--confdir` meegeven: in nextcloud-client 4.0.8 zorgt die vlag ervoor dat
nextcloudcmd enkel de usage-tekst print en stopt (exit 0, geen sync).

Het systeem SHALL standaard GEEN `--silent` meegeven. Die vlag onderdrukt ook
foutuitvoer, waardoor een mislukte sync in de journal alleen "Failed to start"
achterlaat zonder enige reden — op lobos bleef daardoor een storing van 9 tot 16
september 2026 onopgemerkt (419 mislukte runs, nul geslaagde). Een optie `quiet`
kan de vlag desgewenst terugzetten.

#### Scenario: Remote submap en pad-expansie
- **WHEN** een sync `localPath = "~/Nextcloud"` en `remotePath = "/Photos"` heeft
- **THEN** bevat de `ExecStart` `--path /Photos` en het geëxpandeerde absolute lokale pad, gevolgd door de `serverUrl`, en GEEN `--confdir`

#### Scenario: Lokale map wordt aangemaakt
- **WHEN** de service draait terwijl de lokale map nog niet bestaat
- **THEN** maakt `ExecStartPre` de lokale map aan

#### Scenario: Uitvoer zichtbaar bij een mislukte sync
- **WHEN** een sync faalt en `quiet` niet is gezet
- **THEN** bevat de `ExecStart` geen `--silent` en staat de foutuitvoer van `nextcloudcmd` in de journal

#### Scenario: Uitvoer bewust onderdrukken
- **WHEN** `quiet = true` is gezet
- **THEN** bevat de `ExecStart` wél `--silent`

## ADDED Requirements

### Requirement: Meldingsunit aanroepen bij een mislukte sync
Het systeem SHALL de sync-service een of meer units kunnen laten starten zodra hij faalt, zodat
een storing gemeld kan worden in plaats van stil te blijven.

#### Scenario: onFailure geconfigureerd
- **WHEN** `onFailure = [ "notify-signal@%N.service" ]` is gezet
- **THEN** bevat de unit `OnFailure=notify-signal@%N.service` en start systemd die unit bij een fout

#### Scenario: onFailure niet geconfigureerd
- **WHEN** `onFailure` leeg is (default)
- **THEN** bevat de unit geen `OnFailure`-regel
