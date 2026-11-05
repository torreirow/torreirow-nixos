---
# nixos-umuq
title: VAAPI-transcode voor Immich op de HD 500 laten werken
status: completed
type: task
priority: low
created_at: 2026-11-02T22:58:32Z
updated_at: 2026-11-05T14:07:38Z
parent: nixos-ypet
---

Immich 3.3.5 op malandro: h264_vaapi in Immich's transcode faalt met 'Error encoding a frame' (CQP, B-frames), met iHD (intel-media-driver) en met i965, ook met accelDecode=false. Losse ffmpeg -c:v h264_vaapi-tests met beide drivers slagen wel. Nu ffmpeg.accel=disabled (CPU). Uitzoeken: Immich-ffmpeg (unstable libva) vs. driver uit 26.05, B-frames/compression_level, of QSV. Vereist hardware.graphics + accelerationDevices=[/dev/dri/renderD128]. Zie docs/immich.md.

## Summary of Changes

- Oorzaak gevonden (2026-11-05) door Immich's eigen `BaseConfig` in node het ffmpeg-commando te laten maken en dat op malandro te draaien: bij software-decode zonder schaling (bron ≤ 720p, of niet door de GPU te decoderen: mpeg4, H.264 Baseline/motion photos) zet Immich `hwupload` zonder `format=nv12`; iHD én i965 weigeren dat frame. De oude B-frames/CQP/libva-hypothesen bleken niet de oorzaak.
- `modules/immich-vaapi-patch.nix`: kopie van unstable.immich met `format=nv12` vóór `hwupload` (alleen VAAPI); faalt bij een upgrade als de patchplek verandert. Flake-check `immich-vaapi-patch` (9 gevallen, incl. de bug in het origineel).
- `modules/immich.nix`: `hardware.graphics` + intel-media-driver, `LIBVA_DRIVER_NAME=iHD`, alleen `/dev/dri/renderD128`, `ffmpeg.accel = "vaapi"`, `accelDecode = true`.
- Metingen: 1080p H.264 4,4 s → 1,3 s; 4K HEVC 10-bit 8,7 s → 2,1 s.
- Live: small.mkv (mpeg4 640x360) → hw-decode faalt, sw-decode + VAAPI slaagt (h264 640x360); hevc4k10.mp4 → hw-decode + VAAPI (h264 1280x720); 0 terugvallen op de CPU.
- Docs: `docs/immich.md` (VAAPI), CLAUDE.md-index. OpenSpec `immich-vaapi` gearchiveerd.
- Vervolg: nixos-8y1q (upstream melden).
