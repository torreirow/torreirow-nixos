## Why

Video omzetten voor Immich gebeurt op de CPU van malandro (Celeron J3455, 4 trage kernen). Dat
houdt malandro tijdens een upload bezig. De HD 500 kan H.264 hardwarematig encoderen en HEVC
(ook 10-bit) decoderen. Op 2026-11-02 faalde VAAPI in Immich met "Error encoding a frame"; bean
`nixos-umuq`.

Oorzaak (2026-11-05 uitgezocht met Immich's eigen commandogenerator op malandro): bij software-
decode zonder schaling (bron ≤ 720p, of een bron die de GPU niet kan decoderen) maakt Immich
`-vf hwupload` zonder `format=nv12`. Een yuv420p-frame gaat dan onomgezet naar de encoder, en iHD
én i965 weigeren dat ("internal encoding error" / "invalid VASurfaceID"). Met schaling zet
`scale_vaapi=…:format=nv12` het wel om; daarom slaagden losse tests wel.

## What Changes

- Immich-pakket met een kleine patch: in `VaapiSwDecodeConfig.getFilterOptions` `format=nv12`
  vóór `hwupload`. Goedkoop gebouwd: kopie van `unstable.immich` met één gewijzigd bestand, geen
  herbouw vanaf de bron.
- `hardware.graphics` met `intel-media-driver` (iHD), `LIBVA_DRIVER_NAME=iHD` voor immich-server,
  `accelerationDevices = [ "/dev/dri/renderD128" ]`.
- `ffmpeg.accel = "vaapi"`, `accelDecode = true` (Immich valt per video terug op software-decode
  als de GPU de bron niet kan decoderen, en daarna op de CPU).
- Test: flake-check die met de gepatchte `media.js` de ffmpeg-argumenten genereert.

## Capabilities

### Modified Capabilities

- `immich-photos`: requirement "Machine learning uit, video op de CPU" → video via VAAPI.

## Impact

- `modules/immich.nix`, nieuw `modules/immich-vaapi-patch.nix` + test, `flake.nix` (check),
  `docs/immich.md`.
- Immich draait niet meer met `PrivateDevices`; alleen `/dev/dri/renderD128` is toegestaan.
- Bij een Immich-upgrade faalt de build als de patchplek verandert (`--replace-fail`): dan
  controleren of upstream het zelf heeft opgelost.
