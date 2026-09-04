---
# nixos-9596
title: torrlinny migreren naar de generieke services.linny-web module (met Authelia-vhost)
status: completed
type: feature
priority: normal
created_at: 2026-09-04T13:37:47Z
updated_at: 2026-09-04T13:51:46Z
---

modules/torrlinny.nix vervangen door een import van de generieke linny-web NixOS-module (flake github:torreirow/linny-web-theme, nixosModules.linny-web). Aandachtspunten: (1) auth naar de repo omzetten van SSH deploy-key (agenix) naar fine-grained PAT via gitTokenFile, OF de module uitbreiden met optionele SSH-key-auth; (2) de bestaande Authelia-vhost op linny.toorren.net eromheen houden -> NIET de dunne nginx-helper gebruiken maar zelf de vhost definieren met root = config.services.linny-web.webRoot + de authelia-nginx.nix hooks; (3) domain/acmeHost blijven torrlinny-specifiek; (4) verifieren: switch schoon, build draait, site achter Authelia live, keep-last-good werkt. Voorwaarde: linny-web-theme flake gepusht (gedaan, commit 7e07046). Gerelateerd: afgeronde epic nixos-dhh8.

## Summary of Changes

torrlinny gemigreerd naar de gedeelde `services.linny-web` module.

**linny-web-theme (commit 506ba2e):** module uitgebreid met optionele **SSH-deploy-key-auth**
(`gitSshKeyFile`) naast `gitTokenFile` (precies één, assertion). SSH-modus via `GIT_SSH_COMMAND`
(IdentitiesOnly, known_hosts in stateDir). flake-check dekt beide auth-modi; README + CHANGELOG.

**torreirow-nixos:**
- `flake.nix`: input `linny-web` (`github:torreirow/linny-web-theme`, gepind op 506ba2e) +
  in de `outputs`-destructurering + `nixosModules.linny-web` in de malandro modules-lijst.
- `modules/torrlinny.nix`: herschreven tot **dunne wrapper** — behoudt
  `services.torrlinny.{enable,domain,acmeHost}`; zet agenix deploy-key + `services.linny-web`
  (gitSshKeyFile, user=torrlinny, stateDir=/var/lib/torrlinny, webRoot=…/live, baseURL) +
  `SupplementaryGroups=[keys]` op `linny-web-build` + eigen **Authelia-vhost**. Oude
  user/tmpfiles/service/timer/buildScript verwijderd.
- `docs/torrlinny.md` bijgewerkt (unit heet nu `linny-web-build`).

**Geverifieerd op malandro (live):** dry-build + switch schoon; `linny-web-build` bouwt rev 6c5906f
via de SSH-deploy-key; live-symlink ok; checkout `0700` (privé), werkmap `0751`; site → `302
auth.toorren.net` (Authelia); oude `torrlinny-build`-units weg.

**OpenSpec:** `migrate-torrlinny-to-linny-web` (refactor, `skip_specs`), gearchiveerd.
