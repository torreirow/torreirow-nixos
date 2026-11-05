---
# nixos-ypet
title: Immich op malandro (photos.toorren.net) als fotobackup en bron voor de reisapps
status: in-progress
type: epic
priority: normal
created_at: 2026-11-02T21:56:32Z
updated_at: 2026-11-02T23:07:11Z
---

Immich op malandro: automatische fotobackup van de Nothing Phone en foto-bron (API-sleutel) voor
de reisapps MarkMySteps (markmysteps.toorren.net) en OwnSteps (reis.toorren.net).

OpenSpec change (proposal/design/spec/tasks staan al klaar, geen nieuwe propose nodig):
add-immich-photos (openspec/changes/add-immich-photos/). Gebruik tasks.md als plan; de stories
hieronder volgen de taakgroepen 1-4.

Kern:
- services.immich (nixpkgs 2.7.x) op 127.0.0.1:2283, nginx photos.toorren.net, GEEN forward-auth.
- Login via Authelia-OIDC (client immich, two_factor), ook voor de Android-app.
- ML uit (J3455 heeft geen AVX); video via VAAPI.
- Originelen op een eigen JuiceFS-volume `immich`: metadata in PostgreSQL op malandro, data in
  s3://wto-s3-bucket/immich/, client-side versleuteld. Thumbs/encoded-video lokaal op
  /data/external/immich.
- Al gedaan (2026-11-02): IAM-user juicefs-immich + policy juicefs-immich-s3 (alleen immich/),
  secrets/juicefs-immich-env.age (ACCESS_KEY/SECRET_KEY) in secrets.nix (commit f7ba4b3).

Acceptatiecriteria:
- https://photos.toorren.net/api/server/ping geeft pong; geen redirect naar auth.toorren.net.
- OIDC-login via Authelia werkt op web (app: gebruikerstaak 3.2).
- Upload: origineel op /data/juicefs-immich, nieuwe objecten onder immich/ in S3, thumbnail lokaal.
- immich-server stopt als de JuiceFS-mount wegvalt.
- Lifecycle-regels juicefs-noncurrent-180d en immich-noncurrent-180d staan beide in AWS.
- Na rustic-backup: CREATE DATABASE immich in pg-all, juicefs-immich-meta-dump.json bestaat.
- umami, juicefs_sub-replicatie en overige diensten werken na de PostgreSQL-herstart.
- docs/immich.md + CLAUDE.md-indexregel, status-page, PORTS.md, CHANGELOG.

Randvoorwaarden: secrets alleen via ragenx (rbw moet ontgrendeld zijn), nooit waarden tonen;
AWS met AWS_PROFILE=TEC-playground-student01 en het echte aws-binary (rtk-wrapper verminkt
uitvoer); branch system/malandro, niet pushen/PR zonder vraag; flake.nix/flake.lock
(HyprQuickFrame) zijn ongerelateerd werk van de gebruiker: niet meenemen in commits.


## Stand 2026-11-03
Alle agent-stories klaar (w6ip, cv87, kvys, mjvo). Open: gebruikerstaak nixos-3pjm (web-login met 2FA, app op de telefoon, API-sleutel in de reisapps). Vervolg: nixos-umuq (VAAPI).
