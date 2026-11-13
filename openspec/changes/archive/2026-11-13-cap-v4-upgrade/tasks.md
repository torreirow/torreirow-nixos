# Tasks

## 1. Terugweg zekerstellen

- [x] 1.1 Noteer de huidige image-digest (3.1.15) en maak een Valkey-snapshot:
      `docker exec cap-valkey valkey-cli SAVE` + kopie van
      `/data/external/cap/valkey/dump.rdb` naar `/data/external/cap/backup-<datum>.rdb`.
      Verifieer: `docker exec cap-valkey valkey-cli DBSIZE` geeft hetzelfde aantal keys als vóór de
      SAVE en het backupbestand is niet leeg.
- [x] 1.2 Test het terugrolpad droog: start een wegwerp-valkey met die `dump.rdb` en controleer dat
      de site-keys erin zitten (`valkey-cli KEYS '*'` bevat `site:*`/`keys:*`). Verifieer: de
      wegwerp-container toont de keys en wordt daarna verwijderd.
- [x] 1.3 Leg het terugrolcommando vast in `docs/filedrop.md` (digest terug, snapshot terug, secrets
      op v3 opnieuw zetten). Verifieer: het stappenplan is kopieerbaar en noemt de twee
      agenix-bestanden bij naam.

## 2. Module aanpassen

- [x] 2.1 Pin `modules/cap.nix` op `tiago2/cap@sha256:e9cd4884f35ca6bcedb6a27fa92be55813bfe64fe2cae93a084ec8d20e1aebd5`
      (4.0.12) en corrigeer het commentaar (DuckDB/AVX2, niet Bun). Verifieer: `nix eval` van de
      malandro-config geeft die digest en `nix build` van de toplevel slaagt.
- [x] 2.2 Hernoem `REDIS_URL` naar `VALKEY_URL` in de container-env. Verifieer: de gegenereerde
      containerdefinitie (`nix eval .#nixosConfigurations.malandro.config.virtualisation.oci-containers.containers.cap.environment`)
      bevat `VALKEY_URL` en geen `REDIS_URL`.
- [x] 2.3 Voeg het event-volume toe: tmpfiles-regel `d /data/external/cap/events 0755 1000 1000 -`
      en mount `${dataDir}/events:/usr/src/app/data`; zet `DUCKDB_MEMORY_LIMIT=128MB`. Verifieer:
      de gegenereerde containerdefinitie bevat de mount en de env-var, en de tmpfiles-regel staat
      in de gebouwde config.
- [x] 2.4 Zet in de nginx-vhost `proxy_set_header X-Forwarded-For $remote_addr` in plaats van
      `$proxy_add_x_forwarded_for`. Verifieer: `grep X-Forwarded-For` in de gegenereerde
      `nginx.conf` toont `$remote_addr` voor `cap.toorren.net`.

## 3. Uitrollen en basischeck

- [x] 3.1 `nixos-rebuild switch --flake .#malandro` (of `--target-host`) en controleren dat
      `docker-cap` en `docker-cap-valkey` draaien. Verifieer: `docker ps` toont beide als `Up`.
- [x] 3.2 Controleer de container-log op de oude crash en op Valkey-gebruik. Verifieer: geen
      `Illegal instruction`, wel `Cap running`, en `curl -s http://127.0.0.1:3009/health` geeft 200.
- [x] 3.3 Log in op `https://cap.toorren.net` met `ADMIN_KEY` en controleer dat beide site-keys
      (`eaa5abea30`, `92c7e198d7`) bestaan met een "Reset secret"-tag. Verifieer: de keys zijn
      zichtbaar en de tags staan er.
- [x] 3.4 Zet in *Instance settings → Visitor location* de proxy op nginx. Verifieer: de instelling
      is opgeslagen en een challenge-request vanaf een extern adres krijgt een eigen rate-limit-
      bucket (te zien aan de events met het echte client-IP, niet 127.0.0.1).

## 4. Secrets roteren en consumers herdeployen

- [x] 4.1 Reset het secret van key `eaa5abea30` en schrijf het naar `secrets/cap-mailer-secret.age`
      met `agenix -e`. Verifieer: `nix build` van de malandro-config slaagt en het bestand is
      opnieuw versleuteld (nieuwe mtime, agenix decrypt op de host geeft de nieuwe waarde).
- [x] 4.2 Reset het secret van key `92c7e198d7` en werk `CAP_SECRET` in `secrets/filedrop-env.age`
      bij (share-token ongewijzigd laten). Verifieer: het env-bestand bevat nog steeds
      `NEXTCLOUD_SHARE_TOKEN` en de nieuwe `CAP_SECRET`.
- [x] 4.3 Deploy mailer en filedrop opnieuw (`nixos-rebuild switch`) en controleer `/siteverify`
      voor beide keys. Verifieer: beide geven `success: true` met een verse token, en de
      systeem-units `phpfpm-mailer`/`filedrop` zijn actief zonder fouten in de log.

## 5. Acceptatie en documentatie

- [x] 5.1 Verstuur één echt bericht via een contactformulier en doe één echte upload via File Drop,
      beide in een browser (niet met curl). Verifieer: mail komt aan, upload landt in Nextcloud,
      en de widget laadt met de bestaande jsDelivr-versie (0.1.58) — zo niet, widgetversie ophogen
      en opnieuw testen.
- [x] 5.2 Controleer de voetafdruk na de upgrade. Verifieer: `docker stats --no-stream` toont cap
      onder ~150 MB, `free -h` laat geen nieuwe swap-groei zien en het dashboard toont events.
- [x] 5.3 Werk `docs/filedrop.md` bij (Cap 4, `VALKEY_URL`, events-volume, secret-rotatie,
      terugrolpad) en zet een regel in `CHANGELOG.md`. Verifieer: de genoemde paden en
      commandovoeringen kloppen met `modules/cap.nix`.

## Workflow follow-up

- Archiveren van de change zodra de acceptatie is afgerond (zie `~/.claude/docs/openspec-workflow.md`).
