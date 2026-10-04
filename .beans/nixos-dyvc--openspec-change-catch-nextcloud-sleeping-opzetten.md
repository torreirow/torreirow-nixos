---
# nixos-dyvc
title: OpenSpec-change catch-nextcloud-sleeping opzetten
status: completed
type: task
priority: normal
created_at: 2026-10-04T20:58:22Z
updated_at: 2026-10-04T21:02:51Z
parent: nixos-pudl
---

Change aanmaken via `/opsx:propose` met proposal + design + specs + tasks.

Design vastleggen:
- Scope: alleen nxc-vhost, tijdbewuste pagina, connect-timeout omlaag, geen wek-knop.
- Waarom proxy_connect_timeout != upload-timeout (TCP-handshake vs transfer).
- Waarom error_page scoped en niet globaal in commonHttpConfig.
- Waarom proxy_intercept_errors niet nodig is (nginx genereert de connect-fout zelf).



## Summary of Changes
OpenSpec-change `catch-nextcloud-sleeping` aangemaakt: proposal.md, design.md, tasks.md en delta-spec `specs/nextcloud-proxy/spec.md` (ADDED capability). `openspec validate --strict` groen.
