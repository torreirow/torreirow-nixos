## 1. Patch

- [x] 1.1 `modules/immich-vaapi-patch.nix`: kopie van unstable.immich, `format=nv12` vóór `hwupload` in de VAAPI-sw-decode-filters, store-pad omzetten
- [x] 1.2 Flake-check `immich-vaapi-patch`: gegenereerde argumenten (klein/sw-decode bevat `format=nv12,hwupload`, hw-decode ongewijzigd), geen verwijzing naar het oude pad

## 2. Malandro

- [x] 2.1 `modules/immich.nix`: gepatcht pakket, `hardware.graphics` + iHD, `LIBVA_DRIVER_NAME`, `accelerationDevices`, `ffmpeg.accel = "vaapi"`, `accelDecode = true`
- [x] 2.2 malandro bouwt

## 3. Verifiëren (live)

- [ ] 3.1 Na rebuild: `PUT /api/jobs/videoConversion` (force) → "Successfully encoded" zonder "acceleration disabled"
- [ ] 3.2 `vainfo`/journal toont iHD; immich-server heeft alleen renderD128

## 4. Documentatie

- [x] 4.1 `docs/immich.md`: VAAPI-sectie (oorzaak, patch, metingen), tabelrij Video
- [x] 4.2 Spec `immich-photos` bijwerken (delta)
