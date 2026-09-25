---
# nixos-eo2h
title: end-to-end verificatie + Claude Online/Mobile koppelen + documentatie
status: todo
type: task
priority: normal
created_at: 2026-09-25T07:45:27Z
updated_at: 2026-09-25T07:45:40Z
parent: nixos-m0vn
blocked_by:
    - nixos-ce9f
    - nixos-pbph
    - nixos-chcj
---

De acceptatiecriteria van de epic aantoonbaar afvinken en de connectors in Claude configureren.

## Handwerk, buiten de CLI
Het koppelen aan Claude is **niet declaratief** te doen — Claude Online en Mobile zijn niet vanaf
een NixOS-host te configureren. mipmip heeft dit expliciet als non-goal opgenomen. Het is een
formulier: custom connector met de URL en het one-time token.

## Verificaties (de acceptatiecriteria van de epic)
- [ ] `/healthz` via HTTPS: 200 zonder auth
- [ ] `/mcp` zonder token: geweigerd
- [ ] geauthenticeerde MCP-handshake slaagt
- [ ] server bindt een privé-IP (`ss -lntp`), niet `0.0.0.0` of publiek
- [ ] Claude Online: custom connector toevoegen, notities doorzoeken
- [ ] Claude Mobile: idem
- [ ] agent maakt een notitie -> draagt `status: agent-draft` -> staat binnen ~1 min op GitHub
- [ ] **agent probeert een bestaande, niet-gequarantainede notitie te wijzigen -> GEWEIGERD**
      (het bewijs dat optie A werkt; verwacht "requires write:* (or write:inbox ...)")
- [ ] notitie elders bewerken + pushen -> na de pull doorzoekbaar via MCP
- [ ] promotie-flow één keer doorlopen: `status: agent-draft` met de hand weghalen in NeoVim,
      daarna bevestigen dat de agent er niet meer bij kan
- [ ] `linny.toorren.net` werkt nog; `/var/lib/torrlinny/checkout` onaangeraakt; geen agent-notitie
      gewist door de Hugo-build (laat beide een paar cycli draaien)
- [ ] geen tokenliteral of privésleutel in `/nix/store`
- [ ] agent-notitie verschijnt binnen ~4 min op `linny.toorren.net` (de afgesproken latentie)

## Documentatie
- [ ] `docs/linny-mcp.md` schrijven in de stijl van `docs/torrlinny.md`: architectuurplaatje met de
      twee gescheiden checkouts, waarom die scheiding er is, tokenrotatie, en hoe je een draft
      promoveert
- [ ] `CLAUDE.md` een verwijzing geven naar dat doc (contextbestanden-lijst bovenin)
- [ ] `CHANGELOG.md` onder `## NEXT VERSION`
