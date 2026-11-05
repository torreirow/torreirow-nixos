---
# nixos-c8rn
title: fix nextcloud client service
status: completed
type: task
priority: normal
created_at: 2026-10-01T17:25:03Z
updated_at: 2026-11-05T07:56:46Z
---

Fix de errors

Oct 01 19:24:25 lobos nextcloud[2116125]: Migrating old config from "/home/wtoorren/.local/share/Nextcloud" to "/home/wtoorren/.config/Nextcloud"
Oct 01 19:24:25 lobos nextcloud[2116125]: Failed to move the old config directory to its new location ( "/home/wtoorren/.local/share/Nextcloud" to "/home/wtoorren/.config/Nextcloud" )
Oct 01 19:24:25 lobos nextcloud[2116125]: Will move the individual files QList("Documents_sync.log", "Nextcloud_sync.log")
Oct 01 19:24:25 lobos nextcloud[2116125]: Fallback move of  "Documents_sync.log" also failed
Oct 01 19:24:25 lobos nextcloud[2116125]: Fallback move of  "Nextcloud_sync.log" also failed


## Afgerond 2026-11-05
Oorzaak: in ~/.local/share/Nextcloud stonden alleen twee oude logs (Documents_sync.log, Nextcloud_sync.log); de client probeerde ze bij elke start naar ~/.config/Nextcloud te verplaatsen, waar al bestanden met die naam stonden. Config stond al op de nieuwe plek. Fix: map hernoemd naar ~/.local/share/Nextcloud.bak-20261105.
