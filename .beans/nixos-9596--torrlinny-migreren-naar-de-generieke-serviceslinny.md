---
# nixos-9596
title: torrlinny migreren naar de generieke services.linny-web module (met Authelia-vhost)
status: todo
type: feature
created_at: 2026-09-04T13:37:47Z
updated_at: 2026-09-04T13:37:47Z
---

modules/torrlinny.nix vervangen door een import van de generieke linny-web NixOS-module (flake github:torreirow/linny-web-theme, nixosModules.linny-web). Aandachtspunten: (1) auth naar de repo omzetten van SSH deploy-key (agenix) naar fine-grained PAT via gitTokenFile, OF de module uitbreiden met optionele SSH-key-auth; (2) de bestaande Authelia-vhost op linny.toorren.net eromheen houden -> NIET de dunne nginx-helper gebruiken maar zelf de vhost definieren met root = config.services.linny-web.webRoot + de authelia-nginx.nix hooks; (3) domain/acmeHost blijven torrlinny-specifiek; (4) verifieren: switch schoon, build draait, site achter Authelia live, keep-last-good werkt. Voorwaarde: linny-web-theme flake gepusht (gedaan, commit 7e07046). Gerelateerd: afgeronde epic nixos-dhh8.
