---
# nixos-f7di
title: nextcloud-client toevoegen aan home packages (levert nextcloudcmd)
status: completed
type: task
priority: normal
created_at: 2026-08-31T10:50:05Z
updated_at: 2026-08-31T10:59:54Z
parent: nixos-3es6
---

pkgs.nextcloud-client (levert nextcloudcmd) toegevoegd aan home.packages via de module (config = mkIf cfg.enable). Store-path geresolved in de eval-test (nextcloud-client-4.0.8).
