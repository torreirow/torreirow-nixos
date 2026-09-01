---
# nixos-axoq
title: home-manager module home/module/nextcloud-sync/ met options-API
status: completed
type: feature
priority: normal
created_at: 2026-08-31T10:50:05Z
updated_at: 2026-08-31T10:59:54Z
parent: nixos-3es6
---

Module home/module/nextcloud-sync/default.nix + README.md aangemaakt. services.nextcloud-sync met enable, package, credentialsFile, syncs.<naam> (attrsOf submodule: serverUrl, localPath, remotePath, interval, excludeFile, trust, extraArgs). Path-normalisatie voor leidende ~/. Geverifieerd via nix eval (extendModules).
