---
# nixos-xml4
title: Handmatige .netrc + documentatie (0600, app-password)
status: completed
type: task
priority: normal
created_at: 2026-08-31T10:50:05Z
updated_at: 2026-08-31T10:59:54Z
parent: nixos-3es6
---

credentials.example (placeholders) via de module; README + design documenteren: app-password (revocable), mode 0600, en expliciete waarschuwing tegen home.file.".../credentials".text (nix-store-lek 0444). Credential blijft handmatig, buiten repo/store.
