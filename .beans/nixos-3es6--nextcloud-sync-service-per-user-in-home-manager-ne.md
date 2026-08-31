---
# nixos-3es6
title: Nextcloud sync-service per user in home-manager (nextcloudcmd + timer)
status: completed
type: epic
priority: normal
created_at: 2026-08-31T10:49:12Z
updated_at: 2026-08-31T11:33:59Z
---

FIX na live-test: `--confdir` verwijderd uit de nextcloudcmd-aanroep. nextcloud-client 4.0.8 dumpt bij `--confdir` alleen de usage-tekst en stopt (exit 0, geen sync) — server+creds waren aantoonbaar ok (curl PROPFIND HTTP 207). Zonder `--confdir` synct de service correct (getest: ~/Nextcloud gevuld met remote-inhoud, timer draait elke 10 min). Config live in home/linux-desktop.nix (serverUrl https://nxc.toorren.net).
