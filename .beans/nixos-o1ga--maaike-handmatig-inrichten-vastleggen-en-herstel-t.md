---
# nixos-o1ga
title: 'maaike: handmatig inrichten, vastleggen en herstel testen'
status: todo
type: task
priority: normal
tags:
    - handmatig
created_at: 2026-11-04T21:10:32Z
updated_at: 2026-11-04T21:30:47Z
parent: nixos-kzxu
blocked_by:
    - nixos-h295
---

NIET door de agent.
1. Deploy mpenzi; met Maaike via RustDesk: Spotify inloggen, Nextcloud inloggen (browser), Bitwarden inloggen, ZapZap en Signal koppelen (QR), Thunderbird met Gmail.
2. Spotify-prefs vastleggen: `ssh wtoorren@10.77.0.3 sudo cat /home/maaike/.config/spotify/prefs | (cd secrets && ragenx -e spotify-maaike.age)`; controleren met `ragenx -d`; `git add`.
3. `vastleggen-app-defaults` draaien, diff nakijken, committen; opnieuw deployen.
4. Test: `ssh wtoorren@10.77.0.3 sudo herstel-app maaike nextcloud`; Maaike logt opnieuw in.


## Voortgang 2026-11-04
- Spotify en Bitwarden ingelogd door Maaike.
- Stap 2 klaar: `secrets/spotify-maaike.age` (4 autologin-regels, 2 recipients) + regel in `secrets.nix`, commit 8240fde.
