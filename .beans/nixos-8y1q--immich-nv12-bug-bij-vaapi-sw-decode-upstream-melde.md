---
# nixos-8y1q
title: 'Immich: nv12-bug bij VAAPI sw-decode upstream melden'
status: todo
type: task
priority: deferred
created_at: 2026-11-05T14:07:38Z
updated_at: 2026-11-05T14:07:38Z
---

Zie docs/immich.md (VAAPI) en OpenSpec immich-vaapi. In Immich 3.3.5 zet VaapiSwDecodeConfig.getFilterOptions hwupload zonder format=nv12 als er niet geschaald wordt; iHD en i965 falen dan ('internal encoding error'). Wij patchen dit in modules/immich-vaapi-patch.nix. Issue/PR bij immich-app/immich, zodat de patch na een upgrade weg kan.
