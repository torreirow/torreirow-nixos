---
# nixos-s5g5
title: 'maaike: Spotify-prefs via agenix (lobos-patroon)'
status: todo
type: task
created_at: 2026-11-04T21:10:32Z
updated_at: 2026-11-04T21:10:32Z
parent: nixos-kzxu
---

Spotify via agenix, lobos-patroon.
- `secrets/secrets.nix`: `"spotify-maaike.age".publicKeys = users ++ [ mpenzi ];`
- mpenzi: `age.secrets.spotify-maaike = { file; path = "/home/maaike/.config/spotify/prefs"; owner = "maaike"; mode = "0600"; }` alleen als het bestand bestaat (pathExists + warning).
- Controleer dat de map `/home/maaike/.config/spotify` bestaat vóór agenix linkt (tmpfiles).
