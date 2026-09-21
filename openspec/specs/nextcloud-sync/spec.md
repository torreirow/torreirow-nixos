# nextcloud-sync Specification

## Purpose
TBD - created by archiving change add-nextcloud-sync. Update Purpose after archive.

## Requirements

### Requirement: Per-user, per-sync headless Nextcloud-sync module
Het systeem SHALL een home-manager module `services.nextcloud-sync` bieden die per
gedefinieerd sync-paar (`syncs.<naam>`) een oneshot `systemd.user.service` én een
`systemd.user.timer` genereert die `nextcloudcmd` draaien. Bij `enable = false` SHALL
de module niets toevoegen.

#### Scenario: Meerdere sync-paren
- **WHEN** `services.nextcloud-sync.syncs` twee entries `docs` en `foto` bevat en `enable = true`
- **THEN** bestaan `nextcloud-sync-docs.{service,timer}` en `nextcloud-sync-foto.{service,timer}` met elk hun eigen `serverUrl`/`localPath`

#### Scenario: Uitgeschakeld voegt niets toe
- **WHEN** `services.nextcloud-sync.enable = false`
- **THEN** worden er geen `nextcloud-sync-*`-units en geen `nextcloud-client`-package aan de home-configuratie toegevoegd

### Requirement: Credentials nooit in de nix-store
Het systeem SHALL `nextcloudcmd` authenticeren via `--non-interactive`, dat
`$NC_USER` en `$NC_PASSWORD` uit de environment leest, geladen via
`EnvironmentFile=` uit een handmatig bestand (default
`~/.config/nextcloud-sync/credentials`). Het systeem SHALL dit credential NIET via
Nix beheren en dus niet in de nix-store of git plaatsen.

#### Scenario: Credential komt uit een handmatig EnvironmentFile
- **WHEN** de service `nextcloud-sync-docs.service` draait
- **THEN** laadt hij `NC_USER`/`NC_PASSWORD` via `EnvironmentFile=-<credentialsFile>` en geeft `nextcloudcmd` `--non-interactive` mee (geen `-u`/`-p` op de commandline)

#### Scenario: Nette fout bij ontbrekend credential
- **WHEN** het credentials-bestand ontbreekt of `NC_USER`/`NC_PASSWORD` leeg is
- **THEN** faalt de service via `ExecStartPre` met een duidelijke melding die naar het pad en de app-password-instructies verwijst

### Requirement: Timer-cadans zonder overlap
Het systeem SHALL elke sync periodiek triggeren met `OnUnitActiveSec` gelijk aan het
`interval` van het sync-paar (default 10 min), plus een eerste run via `OnActiveSec`,
zodat een trage sync niet overlapt met de volgende run.

#### Scenario: Timer actief na switch
- **WHEN** de home-generatie met een enabled sync-paar is geactiveerd
- **THEN** toont `systemctl --user list-timers` de `nextcloud-sync-<naam>.timer` met de volgende trigger op basis van `OnUnitActiveSec`

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

### Requirement: Meldingsunit aanroepen bij een mislukte sync
Het systeem SHALL de sync-service een of meer units kunnen laten starten zodra hij faalt, zodat
een storing gemeld kan worden in plaats van stil te blijven.

#### Scenario: onFailure geconfigureerd
- **WHEN** `onFailure = [ "notify-signal@%N.service" ]` is gezet
- **THEN** bevat de unit `OnFailure=notify-signal@%N.service` en start systemd die unit bij een fout

#### Scenario: onFailure niet geconfigureerd
- **WHEN** `onFailure` leeg is (default)
- **THEN** bevat de unit geen `OnFailure`-regel

### Requirement: Succesmoment van een sync vastleggen
Het systeem SHALL na elke geslaagde sync het tijdstip daarvan vastleggen in een bestand per
sync-paar, zodat losstaande bewaking kan vaststellen of er recent nog gesynct is zonder de
journal te hoeven doorzoeken.

Het vastleggen SHALL uitsluitend plaatsvinden wanneer de sync daadwerkelijk is geslaagd; een
mislukte sync laat het eerder vastgelegde tijdstip ongemoeid.

#### Scenario: Sync slaagt
- **WHEN** een sync normaal eindigt
- **THEN** is het tijdstip van dat moment vastgelegd voor dat sync-paar

#### Scenario: Sync mislukt
- **WHEN** een sync eindigt met een foutstatus
- **THEN** blijft het eerder vastgelegde tijdstip ongewijzigd

#### Scenario: Meerdere sync-paren
- **WHEN** er meer dan één sync-paar geconfigureerd is
- **THEN** houdt elk paar zijn eigen tijdstip bij, onafhankelijk van de andere

#### Scenario: Locatie leesbaar voor bewaking
- **WHEN** een bewakingsproces het vastgelegde tijdstip wil lezen
- **THEN** is dat beschikbaar op een vast, voorspelbaar pad dat uit de sync-naam volgt
