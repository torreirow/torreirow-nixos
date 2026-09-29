---
# nixos-arqj
title: consent_mode van explicit naar pre-configured
status: todo
type: task
created_at: 2026-09-29T20:00:05Z
updated_at: 2026-09-29T20:00:05Z
parent: nixos-b25k
---

`explicit` is een overblijfsel van de bearer-authz-opzet die is losgelaten; de
dwang bestaat niet meer. Wallos staat al op `pre-configured`.

- [ ] In `modules/authelia.nix` op de client `claude-connector`:
      `consent_mode = "pre-configured"` met `pre_configured_consent_duration`
      (voorstel: `1M`, gelijk aan Wallos)
- [ ] Het commentaar bij die client bijwerken: nu staat er dat `explicit` een
      EIS is van Authelia. Dat gold alleen bij `authelia.bearer.authz` en is
      onjuist geworden — laten staan is misleidender dan weghalen
- [ ] `authelia validate-config` in isolatie draaien VOOR de switch. Een
      ongeldige client laat Authelia niet starten, en die beschermt alles
