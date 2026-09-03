# vaultwarden-restore-test Specification

## Purpose
TBD - created by archiving change add-vaultwarden-restore-test. Update Purpose after archive.
## Requirements
### Requirement: Script gedeployed via home-manager
Het script SHALL als bron in de repo leven (`home/module/vaultwarden-restore-test/`) en via home-manager (`home.file."bin/vaultwarden-restoretest.sh"`, executable) naar `~/bin/vaultwarden-restoretest.sh` gedeployed worden, geïmporteerd via `home/linux-server.nix`.

#### Scenario: Script beschikbaar na switch
- **WHEN** `home-manager switch` is gedraaid op malandro
- **THEN** bestaat `~/bin/vaultwarden-restoretest.sh` en is het uitvoerbaar

### Requirement: Basis restore-test in een wegwerp-container
Het script SHALL zonder extra argumenten de nieuwste snapshot uit de rustic-S3-repo terugzetten, de DB-dump als `db.sqlite3` in de gerestorede datadir plaatsen (reassemble), en een wegwerp-Vaultwarden-container starten op `127.0.0.1:8099` (bridge-netwerk).

#### Scenario: Gerestorede Vaultwarden start en bedient
- **WHEN** de basis-test draait
- **THEN** antwoordt `GET http://127.0.0.1:8099/alive` met HTTP 200 en rapporteert het script het aantal users en ciphers uit de gerestorede DB

#### Scenario: Live instance blijft ongemoeid
- **WHEN** de test draait
- **THEN** blijft de live Vaultwarden-container op poort 8080 ononderbroken draaien en wordt `/var/lib/vaultwarden` niet gewijzigd

### Requirement: Snapshot-selectie
Het script SHALL een `--snapshot <id>` optie bieden om een specifieke backup te testen; zonder die optie gebruikt het `latest`.

#### Scenario: Specifieke snapshot
- **WHEN** het script met `--snapshot <id>` draait
- **THEN** wordt die snapshot teruggezet i.p.v. de nieuwste

### Requirement: Geïsoleerde rbw-crypto-test met TOTP
Met `--rbw` SHALL het script via een strikt geïsoleerde rbw-client (eigen XDG-dirs en eigen `rbw-agent`) inloggen op de gerestorede instance met het echte master-password én een interactieve TOTP-code, en vervolgens de vault ontsleutelen. De echte rbw-config (`~/.config/rbw`) SHALL NIET gewijzigd worden.

#### Scenario: Vault ontsleutelt
- **WHEN** `--rbw` draait en de gebruiker master-password + TOTP invoert
- **THEN** logt de geïsoleerde rbw in, synct, en toont `rbw list` een niet-leeg aantal ontsleutelde items

#### Scenario: Echte rbw-config onaangeroerd
- **WHEN** `--rbw` heeft gedraaid
- **THEN** wijst `~/.config/rbw/config.json` nog steeds naar `https://vw.toorren.net` en is er geen item toegevoegd aan de echte rbw-agent

### Requirement: Opruimen met --destroy
Het script SHALL een `--destroy` optie bieden die alle test-resources idempotent opruimt: de geïsoleerde `rbw-agent`, de wegwerp-container en de werkmap.

#### Scenario: Volledige cleanup
- **WHEN** `--destroy` draait
- **THEN** is de container `vaultwarden-restoretest` weg, de werkmap `/tmp/vw-restoretest` verwijderd, en de geïsoleerde rbw-agent gestopt — ook als een deel al ontbrak (geen fout)

### Requirement: Faalveilige teardown
Het script SHALL bij een fout halverwege (behalve met `--keep`) de reeds aangemaakte resources opruimen via een EXIT-trap, zodat er geen half-opgestarte container of werkmap achterblijft.

#### Scenario: Fout tijdens de run
- **WHEN** een stap faalt tijdens de basis-test en `--keep` niet is gegeven
- **THEN** ruimt de trap de container en werkmap op voordat het script met een foutcode eindigt

