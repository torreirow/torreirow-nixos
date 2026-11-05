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
| ML            | op lobos via Nebula (`http://10.77.0.2:3003`), zie "Machine learning" hieronder |
| Video         | VAAPI op de HD 500 (iHD, hw-decode), met patch; zie "VAAPI" hieronder       |

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

## Machine learning op lobos

De J3455 van malandro heeft geen AVX, dus de ML-dienst (slim zoeken, gezichten, dubbele foto's)
draait op lobos: `modules/immich-ml.nix`, alleen `immich-machine-learning` 3.3.5 uit `unstable`
(zelfde versie als de server), op poort 3003, met `Nice=15` en idle-I/O. Malandro gebruikt hem via
de Nebula-mesh; de Nebula-firewall laat 3003 alleen voor het certificaat `malandro` door en de
host-firewall van lobos houdt de poort dicht op wifi/LAN. Opgezet 2026-11-05 (OpenSpec
`immich-ml-on-lobos`, bean `nixos-esgu`).

- **Lobos uit of in slaap:** Immich controleert de URL elke 30 s en logt alleen bij een wissel
  ("became unhealthy/healthy"). ML-taken van uploads in die tijd mislukken (één waarschuwing per
  taak). Inhalen gaat automatisch met de timer `immich-ml-catchup` (hieronder); met de hand:
  https://photos.toorren.net/admin/queues → Smart Search en Face Detection → **Missing**.
- **Admin-menu:** alleen voor admin-accounts. Het eigen OIDC-account is een gewone gebruiker;
  log in met `immich-admin@toorren.net` (wachtwoord-login) of maak het eigen account admin.

### Inhaal-timer `immich-ml-catchup` (malandro)

`modules/immich-ml-catchup/` (OpenSpec `immich-ml-catchup`, bean `nixos-h8zb`). Elke 10 minuten
pingt hij `http://10.77.0.2:3003/ping`. Was ML de vorige keer onbereikbaar, is het de eerste run,
of is de laatste start ouder dan 6 uur, dan start hij `PUT /api/jobs/smartSearch` en
`/faceDetection` met `force=false` (= Missing). Toestand in `/var/lib/immich-ml-catchup/state`.
Test: `nix build .#checks.x86_64-linux.immich-ml-catchup -L`.

Zonder `secrets/immich-ml-catchup-key.age` staat de timer uit (build-warning). Sleutel maken:

1. Als `immich-admin@toorren.net`: avatar → Account Settings → API Keys → New API Key, naam
   `ml-catchup`, rechten alleen **job.create**. Kopieer de sleutel.
2. `cd secrets && wl-paste | tr -d '\n' | sudo ragenx -e immich-ml-catchup-key.age --ssh-dir /etc/ssh`
3. `git add secrets/immich-ml-catchup-key.age`, committen, malandro rebuilden.
4. Controle: `sudo systemctl start immich-ml-catchup; journalctl -u immich-ml-catchup -n 5`.

Let op: `PUT /api/jobs/:name` is sinds Immich 2.4 deprecated (de opvolger kan alleen pauzeren).
Verdwijnt het bij een upgrade, dan faalt de dienst met een HTTP-fout.
- **Eerste keer:** de modellen (CLIP `ViT-B-32__openai`, gezichten `buffalo_l`) komen bij de eerste
  aanvraag van Hugging Face in `/var/cache/immich-ml`. Daarna één keer **Alle** draaien voor
  Slim zoeken en Gezichtsdetectie, met lobos aan het net.
- **Geheugen:** modellen gaan na 10 minuten zonder werk uit het RAM (`MACHINE_LEARNING_MODEL_TTL`).

## VAAPI (video via de HD 500)

Sinds 2026-11-05 (OpenSpec `immich-vaapi`, bean `nixos-umuq`): `ffmpeg.accel = "vaapi"`,
`accelDecode = true`, `hardware.graphics` met `intel-media-driver` (iHD), `LIBVA_DRIVER_NAME=iHD`
en alleen `/dev/dri/renderD128` voor immich-server.

**Waarom het op 2026-11-02 faalde:** bij software-decode zonder schaling (bron ≤ 720p, of een bron
die de GPU niet kan decoderen) maakt Immich `-vf hwupload` zonder `format=nv12`. Het yuv420p-frame
gaat onomgezet naar de encoder en iHD en i965 weigeren dat ("Failed to end picture encode issue:
24 (internal encoding error)", "Error encoding a frame"). Met schaling zet `scale_vaapi=…:format=nv12`
het wel om, daarom slaagden losse tests. Fix: `modules/immich-vaapi-patch.nix` zet `format=nv12`
vóór `hwupload` (kopie van `unstable.immich` met één gewijzigd bestand; geen herbouw).
Test: `nix build .#checks.x86_64-linux.immich-vaapi-patch -L`. Bij een Immich-upgrade faalt de build
als de patchplek verandert: dan kijken of upstream het heeft opgelost en de patch weghalen.

Gemeten op malandro met Immich's eigen commando (doel 720p H.264):

| Bron                  | CPU   | VAAPI hw-decode | VAAPI sw-decode |
|-----------------------|-------|-----------------|-----------------|
| 1080p H.264 High, 3 s | 4,4 s | 1,3 s           | 3,4 s           |
| 4K HEVC 10-bit, 2 s   | 8,7 s | 2,1 s           | 9,9 s           |

GPU-decode lukt niet voor mpeg4 en H.264 Baseline (o.a. de motion photos); Immich valt dan zelf
terug op software-decode + VAAPI-encode, en pas daarna op de CPU. In de journal:
`Transcoding video … with VAAPI-accelerated encoding and decoding` → `Successfully encoded`.
Mis-loopt het: `Retrying with VAAPI acceleration disabled`.

Testgereedschap (scratch, niet in de repo): Immich's `BaseConfig` in node aanroepen met een
`ffprobe`-json levert exact het ffmpeg-commando; zo is de fout op malandro nagebootst.

## Controle

```bash
systemctl is-active juicefs-immich immich-server redis-immich
curl -s https://photos.toorren.net/api/server/ping            # {"res":"pong"}
curl -s http://10.77.0.2:3003/ping                             # op malandro: pong (lobos aan)
journalctl -u immich-server | grep -i "machine learning"       # healthy/unhealthy-wissels
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
