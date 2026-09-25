---
# nixos-eo2h
title: end-to-end verificatie + Claude Online/Mobile koppelen + documentatie
status: in-progress
type: task
priority: normal
created_at: 2026-09-25T07:45:27Z
updated_at: 2026-09-25T14:12:10Z
parent: nixos-m0vn
blocked_by:
    - nixos-ce9f
    - nixos-pbph
    - nixos-chcj
---

De acceptatiecriteria van de epic aantoonbaar afvinken en de connectors in
Claude configureren.

## Handwerk, buiten de CLI

Het koppelen aan Claude is **niet declaratief** te doen — Claude Online en
Mobile zijn niet vanaf een NixOS-host te configureren. mipmip heeft dit
expliciet als non-goal opgenomen. Het is een formulier: custom connector met
de URL en het one-time token.

## Verificaties (de acceptatiecriteria van de epic)

Uitgevoerd op 2026-09-25 tegen de live host.

[x] /healthz via HTTPS: 200 zonder auth
[x] /mcp zonder token: geweigerd (401, ook bij een ongeldig token)
[x] geauthenticeerde MCP-handshake slaagt (protocol 2025-06-18, 20 tools)
[x] server bindt een privé-IP (127.0.0.1:8096), niet 0.0.0.0 of publiek
[ ] Claude Online: custom connector toevoegen, notities doorzoeken
[ ] Claude Mobile: idem
[x] agent maakt een notitie -> draagt status: agent-draft -> stond binnen een
    minuut op GitHub (commit 15d608d)
[x] **agent probeert een bestaande, niet-gequarantainede notitie te wijzigen ->
    GEWEIGERD** met "requires write:* (or write:inbox for a quarantined draft)".
    De anchor-tekst bestond niet eens in het doel, en tóch ging de weigering over
    de scope: de autorisatiecheck zit vóór de tekstvervanging.
[x] notitie elders bewerken + pushen -> na de pull doorzoekbaar via MCP
[x] promotie-flow doorlopen: agent mocht zijn eigen draft wél wijzigen; na het
    met de hand weghalen van status: agent-draft kwam hij er niet meer bij
[x] linny.toorren.net werkt nog; /var/lib/torrlinny/checkout onaangeraakt; geen
    agent-notitie gewist door de Hugo-build
[x] geen tokenliteral of privésleutel in /nix/store (config bevat alleen paden)
[x] agent-notitie verscheen op linny.toorren.net binnen de afgesproken latentie

## Gevonden en opgelost tijdens de verificatie

1. **keys-groep ontbrak.** /run/keys is root:keys 0750; zonder
   SupplementaryGroups = [ "keys" ] kwam de linny-mcp-user niet bij zijn eigen
   agenix-secrets. Alle vier de units faalden bij de eerste switch.
2. **Host-header.** De MCP-SDK zet DNS-rebinding-bescherming automatisch aan voor
   een loopback-server en weigerde nginx' "Host: linny-mcp.toorren.net" met 403 —
   op élke /mcp-call, ook met een geldig token, terwijl /healthz 200 bleef.
   Opgelost met recommendedProxySettings = false + Host localhost.

Beide zijn nu door modules/linny-mcp_test.py afgedekt (36 checks).

## Documentatie

[x] docs/linny-mcp.md geschreven, inclusief de Host-header-valkuil
[x] CLAUDE.md verwijst ernaar in de contextbestanden-lijst
[x] CHANGELOG.md onder ## NEXT VERSION
