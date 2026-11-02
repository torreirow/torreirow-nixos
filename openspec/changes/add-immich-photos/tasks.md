# Tasks

## 1. Secrets en JuiceFS-volume `immich`

- [ ] 1.1 RSA-sleutel + wachtwoordzin maken (`openssl rand -base64 32` → wachtwoordzin; `openssl genrsa -aes256 -passout file:<pw> 2048` → PEM) en opslaan als `secrets/juicefs-immich-passphrase.age` en `secrets/juicefs-immich-rsa-key.age` via `ragenx -e … < tmpfile` (entries eerst in `secrets/secrets.nix`, `users ++ [ wtoorren_workstation malandro_workstation ]`); tmpfiles met `shred -u`. Vereist een ontgrendelde `rbw`; zo niet: vraag de gebruiker `rbw unlock`; verify: `ragenx -d <x>.age | wc -c` > 0, zonder waarden te tonen
- [ ] 1.2 PostgreSQL-database `juicefs_immich_meta` + rol op malandro (declaratief via `services.postgresql.ensureDatabases/ensureUsers` of een oneshot), toegang via de unix-socket zonder wachtwoord in de nix-store (D2); verify: `psql` als die rol maakt verbinding
- [ ] 1.3 `modules/juicefs-immich.nix`: agenix-secrets (env, rsa-key, passphrase), eenmalige `juicefs format` als oneshot die niets doet als het volume al bestaat (`juicefs status` slaagt), mountdienst `juicefs-immich` op `/data/juicefs-immich` met cache `/var/cache/juicefs-immich` (D2); import in `hosts/malandro/configuration.nix`; `git add -N` voor nieuwe bestanden vóór de rebuild; verify: rebuild slaagt, `systemctl is-active juicefs-immich`, `juicefs status` toont `Name: immich`, `EncryptAlgo` gezet, `TrashDays: 30`
- [ ] 1.4 Schrijf-/leestest op de mount en controle in S3; verify: testbestand schrijven, `sync`, nieuw object onder `immich/chunks/` (met `aws s3 ls … --recursive | sort | tail`, het echte aws-binary), terug lezen, verwijderen; met de Immich-sleutels geeft een `GetObject` op `juicefs/` of `rustic-backup/` `AccessDenied`
- [ ] 1.5 S3-lifecycle: huidige configuratie opslaan, `immich-noncurrent-180d` toevoegen naast `juicefs-noncurrent-180d` (D8), profiel `TEC-playground-student01`; verify: `get-bucket-lifecycle-configuration` toont beide regels

## 2. Immich-dienst

- [ ] 2.1 `secrets/immich-oidc.age` (plaintext client-secret, `openssl rand -hex 32`) via ragenx; hash met `authelia crypto hash generate argon2` en OIDC-client `immich` in `modules/authelia.nix` (D5), inclusief `app.immich:///oauth-callback`; verify: rebuild slaagt, `authelia` actief, `https://auth.toorren.net/.well-known/openid-configuration` bereikbaar
- [ ] 2.2 `modules/immich.nix`: `services.immich` (host 127.0.0.1, port 2283, `mediaLocation` op de JuiceFS-mount, ML uit, `accelerationDevices`, `settings` met oauth + ffmpeg vaapi, client-secret via `secretSettings`), `BindPaths` voor `thumbs/` en `encoded-video/` naar `/data/external/immich` (D3), afhankelijkheid van de mount (D4); import in `hosts/malandro/configuration.nix`; verify: `nix build .#nixosConfigurations.malandro.config.system.build.toplevel` slaagt (bij lange bouwtijd: bouwen vanaf lobos, zie `docs/nix-build-throttling.md`)
- [ ] 2.3 nginx-vhost `photos.toorren.net` zonder forward-auth (D5); verify: `curl -s https://photos.toorren.net/api/server/ping` geeft `{"res":"pong"}` en `/` geeft geen redirect naar auth.toorren.net
- [ ] 2.4 Rebuild + controle van de gedeelde PostgreSQL na de herstart (VectorChord in `shared_preload_libraries`); verify: `systemctl is-active postgresql immich-server redis-immich`, umami `/api/heartbeat` ok, `pg_stat_subscription` van `juicefs_sub` loopt nog, geen `immich-machine-learning`-unit
- [ ] 2.5 Mount-afhankelijkheid testen; verify: `systemctl stop juicefs-immich` stopt ook `immich-server`; `systemctl start immich-server` start de mount weer mee; geen bestanden in de onderliggende map `/data/juicefs-immich` als de mount weg is
- [ ] 2.6 Eerste admin-account aanmaken (wachtwoord via ragenx/rbw opslaan, niet in de repo), OAuth-login op de webinterface testen; verify: inloggen via "Inloggen met Authelia" lukt; testupload komt onder `/data/juicefs-immich` en de thumbnail onder `/data/external/immich`; een video-upload wordt omgezet met VAAPI (log van de transcode-job)

## 3. Koppelingen

- [ ] 3.1 API-sleutel voor de reisapps aanmaken in Immich (Accountinstellingen → API-sleutels) en vastleggen hoe die in MarkMySteps (Instellingen → Immich) en OwnSteps in te vullen is; Immich-URL binnen malandro testen vanuit beide containers; verify: vanuit de markmysteps-api- en ownsteps-container geeft `GET /api/server/ping` op de gebruikte URL `pong`
- [ ] 3.2 Gebruikerstaak (telefoon, niet door de agent): Immich-app op de Nothing Phone, server `https://photos.toorren.net`, OAuth-login, back-up aan (alleen wifi); valt de custom scheme in Authelia af, dan de fallback `mobileRedirectUri` uit D5 toepassen; verify: de gebruiker bevestigt login + eerste geüploade foto

## 4. Backup, monitoring en documentatie

- [ ] 4.1 `modules/rustic-backup.nix`: `juicefs dump` van `juicefs_immich_meta` naar `/var/backup/db/juicefs-immich-meta-dump.json` (zelfde patroon als `juicefsMetaDumpScript`); verify: `systemctl start rustic-backup.service` → Result success, het dumpbestand bestaat en is geldige JSON met `Setting.Name == "immich"`, `pg-all.sql.zst` bevat `CREATE DATABASE immich`
- [ ] 4.2 `immich-server` en `juicefs-immich` in `nativeServices` van `modules/status-page.nix`; poort 2283 in `PORTS.md`; verify: status.toorren.net meldt beide gezond
- [ ] 4.3 `docs/immich.md` (opzet, JuiceFS-volume, OIDC + fallback, API-sleutels reisapps, backup/herstel, upgrade) + indexregel in `CLAUDE.md`; CHANGELOG-regel onder `## NEXT VERSION`; verify: docs noemen mount, prefix, secrets, herstelstappen
- [ ] 4.4 Geheugen na een dag meten; verify: `free -h` en `systemctl status immich-server` (Memory) genoteerd in `docs/immich.md`; zo nodig `MemoryHigh` gezet
