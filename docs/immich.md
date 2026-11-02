# Immich (photos.toorren.net)

Fotobackup van de telefoon en foto-bron voor de reisapps (MarkMySteps, OwnSteps) via een
API-sleutel. Login via Authelia-OIDC. Opgezet 2026-11-02 (OpenSpec `add-immich-photos`,
beans-epic `nixos-ypet`).

```
Immich-app / browser / reisapps --> nginx photos.toorren.net (geen forward-auth)
  --> immich-server 127.0.0.1:2283 (Immich 3.3.5 uit unstable)
        |-- PostgreSQL 16 db immich (VectorChord), redis-immich
        |-- /data/juicefs-immich/immich   library/ upload/ profile/ backups/
        |     = JuiceFS-volume "immich" --> s3://wto-s3-bucket/immich/ (versleuteld)
        '-- thumbs/ encoded-video/  (bind)  --> /data/external/immich (lokaal)
```

| Onderdeel     | Waarde                                                                      |
|---------------|-----------------------------------------------------------------------------|
| Code          | `modules/immich.nix`, `modules/juicefs-immich.nix`, unstable-module in `flake.nix` |
| Versie        | Immich 3.3.5 (`unstable.immich` + de module uit dezelfde input)              |
| Admin         | `immich-admin@toorren.net`, wachtwoord in `secrets/immich-admin-password.age` |
| OIDC          | Authelia-client `immich` (`two_factor`), secret `secrets/immich-oidc.age`    |
| JuiceFS-meta  | PostgreSQL `juicefs_immich`, rol `juicefs_immich` (peer via identMap van root) |
| JuiceFS-data  | `s3://wto-s3-bucket/immich/`, IAM-user `juicefs-immich` (alleen `immich/`)   |
| Secrets JFS   | `juicefs-immich-env.age` (S3), `-passphrase.age` (`JFS_RSA_PASSPHRASE`), `-rsa-key.age` (PEM) |
| ML            | uit (J3455 heeft geen AVX)                                                  |
| Video         | CPU (`ffmpeg.accel = "disabled"`), zie "VAAPI" hieronder                    |

## Waarom zo

- **Eigen JuiceFS-volume, metadata op malandro:** de Nextcloud-JuiceFS is op malandro read-only
  en zijn metadata staat op bobadela1, die om 23:00 uitgaat.
- **Immich 3 uit unstable:** nixpkgs 26.05 heeft alleen 2.7.5, gemarkeerd als insecure (geen
  updates, CVE-2026-59258, CVE-2026-82272). Pakket én module komen uit `unstable`, anders passen
  ze niet bij elkaar. Bij de overstap naar 26.11 kan dat blok uit `flake.nix` weg.
- **Geen forward-auth:** de app, de API-sleutels van de reisapps en deellinks werken niet achter
  Authelia's `auth_request`. Login loopt via OIDC.
- **Thumbnails lokaal:** opnieuw te maken en vaak gelezen; alleen originelen naar S3.
- **Immich stopt zonder mount:** `BindsTo=juicefs-immich.service` en een `mountpoint`-check in
  `ExecStartPre`. Getest: mount stoppen stopt Immich, Immich starten brengt de mount mee, en de
  onderliggende map blijft leeg.

## Inloggen en de telefoon

1. Web: <https://photos.toorren.net> → **Inloggen met Authelia** (2FA). Het eerste OIDC-account
   wordt automatisch aangemaakt (`autoRegister`); dat is een gewone gebruiker. Admin-taken met
   `immich-admin@toorren.net` (of maak je eigen account admin via Administratie → Gebruikers).
2. App (Nothing Phone): server `https://photos.toorren.net` → OAuth. Redirect
   `app.immich:///oauth-callback` staat in Authelia. Lukt dat niet: in `modules/immich.nix`
   `mobileOverrideEnabled = true` + `mobileRedirectUri =
   "https://photos.toorren.net/api/oauth/mobile-redirect"` en die URI in de Authelia-client.
3. Back-up aanzetten in de app (instelling "alleen via wifi" aanbevolen).

Instellingen staan in `services.immich.settings` (Nix). De web-UI toont ze dan alleen-lezen.

## Reisapps koppelen (API-sleutel)

API-sleutels horen bij een gebruiker: maak ze aan met **je eigen** (OIDC-)account, want daar
staan de telefoonfoto's. Immich → Accountinstellingen → API-sleutels → nieuw (rechten: lezen van
assets/albums volstaat).

- MarkMySteps: Instellingen → Immich → URL `https://photos.toorren.net` + sleutel → Verbinden.
- OwnSteps: Immich-koppeling in de instellingen, zelfde URL en sleutel.

Beide containers bereiken `https://photos.toorren.net/api/server/ping` (getest 2026-11-02).

## Backup en herstel

- Immich-database: in `pg_dumpall` (`/var/backup/db/pg-all.sql.zst`).
- JuiceFS-metadata: `juicefs-immich-meta-dump.service` → `/var/backup/db/juicefs-immich-meta-dump.json`
  (secret-key verwijderd door juicefs), mee in rustic.
- Data: in S3 zelf; versioning + lifecycle `immich-noncurrent-180d` (oude versies 180 dagen).
  JuiceFS-prullenbak 30 dagen.

Herstel:

```bash
juicefs load "postgres://…/juicefs_immich?…" juicefs-immich-meta-dump.json
juicefs config "<meta-url>" --access-key … --secret-key …   # uit juicefs-immich-env.age
JFS_RSA_PASSPHRASE=… juicefs mount "<meta-url>" /data/juicefs-immich
# daarna de immich-database uit pg-all terugzetten; thumbnails opnieuw laten maken
# (Administratie → Taken → Thumbnails genereren).
```

## VAAPI (nog niet werkend)

Getest 2026-11-02 met iHD (intel-media-driver) en i965: losse `ffmpeg -c:v h264_vaapi`-tests op
`/dev/dri/renderD128` slagen, maar Immich's eigen transcode faalt met "Error encoding a frame"
(CQP, B-frames), ook met `accelDecode = false`. Immich viel dan terug op de CPU. Daarom nu
meteen CPU. Vervolg: bean `nixos-umuq`. Aanzetten vraagt `hardware.graphics` (+ driver),
`accelerationDevices = [ "/dev/dri/renderD128" ]` en `ffmpeg.accel = "vaapi"`.

## Controle

```bash
systemctl is-active juicefs-immich immich-server redis-immich
curl -s https://photos.toorren.net/api/server/ping            # {"res":"pong"}
sudo runuser -u postgres -- juicefs status "postgres://postgres@/juicefs_immich?host=/run/postgresql&sslmode=disable" | jq .Setting.Name
aws s3 ls s3://wto-s3-bucket/immich/ --recursive | sort | tail   # het echte aws-binary, niet via rtk
```

Geheugen bij de start (2026-11-02, nog leeg): immich-server ±700 MB, redis 5 MB, JuiceFS 55 MB;
malandro had daarna 4,0 GB beschikbaar.

## Valkuilen

- **pg_hba:** `modules/docseal.nix` zet `services.postgresql.authentication` met `mkOverride 10`.
  Een eigen regel moet daarom ook `mkOverride 10` (+ `mkBefore`) zijn, anders wordt hij genegeerd.
- **ensureDBOwnership** eist dat rol en database dezelfde naam hebben (`juicefs_immich`).
- **Twee sessies die tegelijk rebuilden** draaiden elkaars generatie terug (2026-11-02 23:41).
  Rebuild malandro vanuit één sessie tegelijk.
