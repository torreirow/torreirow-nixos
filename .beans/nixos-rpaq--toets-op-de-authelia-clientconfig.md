---
# nixos-rpaq
title: Toets op de Authelia-clientconfig
status: completed
type: task
priority: normal
created_at: 2026-09-29T20:00:28Z
updated_at: 2026-09-29T20:08:40Z
parent: nixos-b25k
---

Er is nu geen enkele test op `modules/authelia.nix`, terwijl dat bestand alle
vhosts beschermt. Deze twee instellingen zijn bovendien precies het soort dat
ongemerkt terugvalt.

- [x] Toets in de stijl van `modules/linny-mcp_test.py` (`nix eval --apply` op de
      opgebouwde malandro-config):
      - `claude-connector` heeft `consent_mode = "pre-configured"` met een duur
      - die client verwijst naar het lifespan-profiel
      - het profiel heeft `access_token = "1h"` — borgt dat alleen de
        refresh-token verlengd is
      - `wallos` gebruikt het profiel NIET
      - het `legacy`-authz-endpoint bestaat nog naast `mcp` (dat verdween eerder
        en legde alle vhosts plat)
