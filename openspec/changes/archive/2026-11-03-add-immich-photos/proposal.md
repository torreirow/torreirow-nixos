# Immich op malandro (photos.toorren.net)

## Why

De reisapps die nu ter proef draaien (MarkMySteps op `markmysteps.toorren.net`, OwnSteps op
`reis.toorren.net`) kunnen foto's uit een eigen Immich-server halen via een API-sleutel. Ze
bewaren dan alleen verwijzingen en geen kopieën. Daarnaast is Immich een automatische backup van
de foto's op de Nothing Phone. Er draait nu geen fotodienst op malandro.

## What Changes

- **Immich** via de NixOS-module `services.immich` (nixpkgs, 2.7.x) op `127.0.0.1:2283`, achter
  nginx op `https://photos.toorren.net`. **Geen** Authelia forward-auth: de Immich-app, de
  API-sleutels van de reisapps en de deellinks moeten zonder werken (zelfde reden als OwnSteps).
- **Inloggen via Authelia-OIDC**: een nieuwe OIDC-client `immich` in `modules/authelia.nix`,
  zodat web én de Android-app inloggen met het Authelia-account (2FA).
- **Machine learning uit** (`machine-learning.enabled = false`): de Celeron J3455 heeft geen AVX.
  Later eventueel ML op lobos (buiten deze change).
- **Opslag van de originelen op een eigen JuiceFS-volume** `immich`:
  - metadata in PostgreSQL op **malandro** (database `juicefs_immich`), want bobadela1
    staat 's nachts uit en de bestaande Nextcloud-mount op malandro is read-only;
  - data in `s3://wto-s3-bucket/immich/`, met de IAM-user `juicefs-immich` (bestaat al, policy
    `juicefs-immich-s3`: alleen dit prefix) en `secrets/juicefs-immich-env.age` (bestaat al);
  - client-side versleuteld (`--encrypt-rsa-key`, eigen sleutel en wachtwoordzin in agenix);
  - mount `/data/juicefs-immich` (lezen en schrijven), lokale cache op `/var/cache/juicefs-immich`.
- **Thumbnails en omgezette video lokaal** op `/data/external/immich` (opnieuw te maken, vaak
  gelezen), via bind-mounts in de Immich-dienst.
- **Video-omzetten op de CPU**. VAAPI op de Intel HD 500 is geprobeerd maar faalde in
  Immich's transcode (vervolg-bean `nixos-umuq`).
- **Immich 3.3.5 uit `unstable`** (pakket + module): 26.05 heeft alleen 2.7.5, als insecure
  gemarkeerd.
- **S3-lifecycle**: regel `immich-noncurrent-180d` voor `immich/`, naast de bestaande regel
  `juicefs-noncurrent-180d`.
- **Backup**: de Immich-database zit vanzelf in de nachtelijke `pg_dumpall`; de JuiceFS-metadata
  van het nieuwe volume gaat als `juicefs dump` mee in de rustic-backup (zelfde patroon als
  `juicefs-meta-dump`).
- **Status-page, PORTS.md, `docs/immich.md`** en een indexregel in `CLAUDE.md`.

## Capabilities

### New Capabilities

- `immich-photos`: fotoserver met telefoonbackup, OIDC-login en een API voor de reisapps, met de
  originelen versleuteld op een eigen JuiceFS-volume in S3.

### Modified Capabilities

(geen; de Nextcloud-JuiceFS en zijn spec blijven ongewijzigd)

## Impact

- Nieuwe modules: `modules/immich.nix`, `modules/juicefs-immich.nix`; import in
  `hosts/malandro/configuration.nix`.
- Gewijzigd: `modules/authelia.nix` (OIDC-client), `modules/rustic-backup.nix` (meta-dump),
  `modules/status-page.nix`, `secrets/secrets.nix`, `PORTS.md`, `CLAUDE.md`.
- **Gedeelde PostgreSQL 16 op malandro**: Immich heeft de VectorChord-extensie nodig. De module
  zet die in `shared_preload_libraries`, wat een **herstart van PostgreSQL** betekent (raakt
  umami, de JuiceFS-replica van Nextcloud, linny enz. kort).
- AWS (account 760178553019, profiel `TEC-playground-student01`): lifecycle-configuratie van
  `wto-s3-bucket` uitbreiden.
- Geheugen: malandro (7,6 GB) heeft ±4 GB beschikbaar en gebruikt al swap. Immich-server zonder
  ML vraagt ±1–1,5 GB.
