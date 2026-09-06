---
# nixos-6uat
title: HTTPS-clone met fine-grained PAT (gitTokenFile) + permissie-model (prive checkout, wereld-leesbare output)
status: completed
type: task
priority: normal
created_at: 2026-09-04T08:32:49Z
updated_at: 2026-09-04T11:37:58Z
parent: nixos-dhh8
---

Clone/fetch via HTTPS met git -c http.<host>.extraheader Authorization Bearer token uit gitTokenFile -> token niet in URL/proceslijst. Permissies: stateDir 0751 (traverseerbaar, niet listbaar), builds 0755 + DEST chmod -R a+rX (wereld-leesbare output), checkout chmod 0700 (prive notities blijven prive). Optionele fence.py-preprocessing alleen als het bestand in de checkout bestaat.
