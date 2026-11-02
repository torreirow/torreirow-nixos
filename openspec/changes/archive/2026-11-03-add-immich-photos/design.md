# Design: Immich op malandro

## Context

```
Nothing Phone (Immich-app) --+
browser (photos.toorren.net) +--> nginx --> immich-server 127.0.0.1:2283
MarkMySteps / OwnSteps ------+            |-- PostgreSQL 16 (db immich, VectorChord)
  (API-sleutel)                           |-- redis (module)
                                          |-- mediaLocation /data/juicefs-immich/immich
                                          |     library/ upload/ profile/ backups/  -> JuiceFS -> S3 immich/
                                          |     thumbs/ encoded-video/ (bind) -> /data/external/immich (lokaal)
                                          '-- /dev/dri/renderD128 (VAAPI)
login: Immich OAuth -> Authelia OIDC (auth.toorren.net), client "immich"
```

- malandro: Celeron J3455 (4 cores, SSE4.2, **geen AVX**), 7,6 GB RAM, PostgreSQL 16 (nog geen
  `shared_preload_libraries`), wildcard-DNS `*.toorren.net` en ACME-cert `toorren.net`.
- nixpkgs: `services.immich` 2.7.5 met opties `mediaLocation`, `host`, `port`,
  `machine-learning.enabled`, `database`, `redis`, `accelerationDevices`, `settings`,
  `secretSettings`, `secretsFile`, `environment`.
- AWS: `wto-s3-bucket` (eu-central-1), versioning aan, SSE-S3 (AES256), Block Public Access
  sinds 2026-11-02 weer **aan**. IAM-user `juicefs-immich` met inline policy `juicefs-immich-s3`
  (ListBucket op prefix `immich/`, Get/Put/Delete op `immich/*`) bestaat al;
  `secrets/juicefs-immich-env.age` bevat `ACCESS_KEY` en `SECRET_KEY` en staat in
  `secrets/secrets.nix`.

## Goals / Non-Goals

**Goals:** telefoonbackup via de Immich-app, OIDC-login via Authelia (web en app), API-sleutels
voor MarkMySteps en OwnSteps, originelen versleuteld in S3, herstelbaar uit de backup.

**Non-Goals:** machine learning (gezichten, slim zoeken), import van de Nextcloud-foto's
(external library), een tweede kopie buiten AWS, ML op lobos.

## Decisions

### D1. NixOS-module i.p.v. container
`services.immich` levert server, redis en de database-setup. Past bij umami en vikunja-signal
(native). Alternatief docker-compose van upstream: meer onderhoud en een eigen Postgres.

### D2. Eigen JuiceFS-volume met metadata op malandro
De Nextcloud-JuiceFS kan niet: malandro heeft hem read-only en zijn metadata staat op bobadela1,
die om 23:00 uitgaat. Een tweede volume `immich` met metadata in de lokale PostgreSQL (database
`juicefs_immich`) is onafhankelijk van bobadela1.

- Format (eenmalig, als root, met de env uit agenix):
  `juicefs format --storage s3 --bucket https://wto-s3-bucket.s3.eu-central-1.amazonaws.com
  --encrypt-rsa-key <key.pem> --trash-days 30 "<meta-url>" immich`.
  De volumenaam `immich` maakt het objectprefix `immich/` (zoals de Nextcloud-volume `juicefs`
  in `juicefs/` schrijft), en dat valt precies onder de IAM-policy.
- Meta-URL via de unix-socket, zonder wachtwoord in de nix-store, bijvoorbeeld
  `postgres://juicefs_immich@/juicefs_immich?host=/run/postgresql&sslmode=disable` met een
  eigen rol en peer/ident-mapping, of het `runuser -u postgres`-patroon uit
  `modules/rustic-backup.nix`. Kies wat met de bestaande `services.postgresql`-config werkt.
- Mount-unit `juicefs-immich` (systemd service zoals `modules/juicefs-nextcloud-mount.nix`):
  `juicefs mount --cache-dir /var/cache/juicefs-immich --cache-size 5120 -o allow_other ...`,
  `EnvironmentFile` = agenix-env (S3-sleutels) en de RSA-wachtwoordzin via `JFS_RSA_PASSPHRASE`
  uit een agenix-bestand; `After/Requires` op `postgresql.service` en `network-online.target`.
- Nieuwe secrets (via `ragenx`, nooit tonen): `juicefs-immich-rsa-key.age` (PEM, versleuteld met
  de wachtwoordzin, `openssl genrsa -aes256`) en `juicefs-immich-passphrase.age`.

### D3. Thumbnails en video lokaal
Immich schrijft alles onder `mediaLocation`. Originelen (`library/`, `upload/`, `profile/`,
`backups/`) blijven op JuiceFS; `thumbs/` en `encoded-video/` worden via
`systemd.services.immich-server.serviceConfig.BindPaths` naar `/data/external/immich/...`
gelegd. Die zijn opnieuw te maken (Immich-job "Generate thumbnails") en worden vaak gelezen.

### D4. Immich wacht op de mount
`immich-server` krijgt `After`/`Requires`/`BindsTo` op de JuiceFS-mountdienst en
`RequiresMountsFor = /data/juicefs-immich`. Valt JuiceFS weg, dan stopt Immich in plaats van
in de lege onderliggende map te schrijven. Immich controleert zelf ook de `.immich`-markers per
map en weigert te starten als die ontbreken.

### D5. OIDC via Authelia, geen forward-auth
- Client in `modules/authelia.nix` (patroon wallos/invoiceplane): `client_id = "immich"`,
  `client_secret` = argon2-hash (plaintext in `secrets/immich-oidc.age`), `authorization_policy
  = "two_factor"`, `token_endpoint_auth_method = "client_secret_post"`, scopes
  `openid profile email`, consent `pre-configured`.
- `redirect_uris`: `https://photos.toorren.net/auth/login`,
  `https://photos.toorren.net/user-settings`, `app.immich:///oauth-callback`.
- Immich `settings.oauth`: `enabled = true`, `issuerUrl = "https://auth.toorren.net"`,
  `clientId = "immich"`, secret via `secretSettings` (bestand uit agenix), `autoRegister =
  true`, `buttonText = "Inloggen met Authelia"`. Wachtwoord-login blijft aan voor het
  admin-account tot OIDC bewezen werkt (web én app).
- **Fallback** als Authelia de custom scheme `app.immich:///oauth-callback` weigert: Immich
  `mobileOverrideEnabled = true` met `mobileRedirectUri =
  "https://photos.toorren.net/api/oauth/mobile-redirect"` en die URI als redirect in Authelia.
- nginx `photos.toorren.net`: `forceSSL`, `useACMEHost = "toorren.net"`, `proxyWebsockets`,
  `client_max_body_size 50000M`, `proxy_read_timeout`/`proxy_send_timeout 600s`,
  `proxy_request_buffering off`. Geen `auth_request`.

### D6. ML uit, video op de CPU
`machine-learning.enable = false`. VAAPI is getest (iHD en i965 via `hardware.graphics`,
`accelerationDevices = [ "/dev/dri/renderD128" ]`, ook met `accelDecode = false`): losse
`h264_vaapi`-tests slaagden, maar Immich's transcode faalde met "Error encoding a frame" en viel
terug op de CPU. Daarom `ffmpeg.accel = "disabled"` en `accelerationDevices = [ ]`; VAAPI is
vervolg-bean `nixos-umuq`.

### D9. Immich 3 uit unstable
nixpkgs 26.05 levert `immich-2.7.5` met `knownVulnerabilities` (end-of-life, CVE-2026-59258,
CVE-2026-82272). In `flake.nix` worden voor malandro de 26.05-module uitgeschakeld
(`disabledModules`) en de module uit de `unstable`-input geïmporteerd; `package =
unstable.immich` (3.3.5, in de binaire cache). VectorChord (1.1.1) is in beide gelijk.

### D7. Backup en herstel
- Immich-database: zit in de bestaande `pg_dumpall` (`/var/backup/db/pg-all.sql.zst`).
- JuiceFS-metadata `juicefs_immich`: extra `juicefs dump` naar
  `/var/backup/db/juicefs-immich-meta-dump.json` in `modules/rustic-backup.nix`, naast de
  bestaande `juicefs-meta-dump`. De data zelf staat al in S3 (versioning + lifecycle).
- Herstel: `juicefs load` + `juicefs config --access-key/--secret-key`, mount met
  `JFS_RSA_PASSPHRASE`; de sleutels staan in agenix in de repo.

### D8. S3-lifecycle
`put-bucket-lifecycle-configuration` **vervangt** de hele configuratie. Daarom: eerst
`get-bucket-lifecycle-configuration` opslaan, regel `immich-noncurrent-180d` (Filter `Prefix:
immich/`, `NoncurrentVersionExpiration 180`, `ExpiredObjectDeleteMarker true`) toevoegen en
de bestaande `juicefs-noncurrent-180d` ongewijzigd laten. AWS CLI met
`AWS_PROFILE=TEC-playground-student01`; gebruik het echte `aws`-binary (de rtk-wrapper verminkt
de uitvoer).

## Risks / Trade-offs

- **PostgreSQL-herstart** door `shared_preload_libraries` (VectorChord) → korte onderbreking van
  alle databases op malandro. Doe het in één rebuild en controleer daarna umami, de
  juicefs-replicatie (`pg_stat_subscription`) en linny.
- **Geheugen**: malandro gebruikt al swap. Meet na de start (`systemctl status immich-server`,
  `free -h`); stel eventueel `MemoryHigh` in.
- **Eerste import traag** op de Celeron (thumbnails, video). Accepteren.
- **Bouwtijd**: immich is groot; staat het niet in de cache, dan bouwen vanaf lobos
  (`docs/nix-build-throttling.md`).
- **Één AWS-account** voor data en backup (bekend, buiten deze change). Het origineel staat op
  de telefoon.

## Migration Plan

1. Secrets + JuiceFS-volume formatteren en mounten; schrijf-/leestest.
2. Lifecycle-regel in AWS.
3. Immich + Authelia-client + nginx in één rebuild (PostgreSQL herstart).
4. Eerste admin-account, OIDC testen (web), API-sleutel voor de reisapps.
5. Backup-dump, status-page, docs.
Rollback: module-import weghalen en rebuilden; het JuiceFS-volume en de bucket-data blijven
staan.
