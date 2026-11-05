---
# nixos-umuq
title: VAAPI-transcode voor Immich op de HD 500 laten werken
status: in-progress
type: task
priority: low
created_at: 2026-11-02T22:58:32Z
updated_at: 2026-11-05T12:51:49Z
parent: nixos-ypet
---

Immich 3.3.5 op malandro: h264_vaapi in Immich's transcode faalt met 'Error encoding a frame' (CQP, B-frames), met iHD (intel-media-driver) en met i965, ook met accelDecode=false. Losse ffmpeg -c:v h264_vaapi-tests met beide drivers slagen wel. Nu ffmpeg.accel=disabled (CPU). Uitzoeken: Immich-ffmpeg (unstable libva) vs. driver uit 26.05, B-frames/compression_level, of QSV. Vereist hardware.graphics + accelerationDevices=[/dev/dri/renderD128]. Zie docs/immich.md.
