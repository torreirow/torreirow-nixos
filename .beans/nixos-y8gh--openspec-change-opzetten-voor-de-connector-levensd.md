---
# nixos-y8gh
title: OpenSpec-change opzetten voor de connector-levensduur
status: completed
type: task
priority: normal
created_at: 2026-09-29T20:00:05Z
updated_at: 2026-09-29T20:04:04Z
parent: nixos-b25k
---

Het gedrag dat hier verandert staat beschreven in de capability
`linny-mcp-oidc` (gearchiveerde change `add-linny-mcp-oidc`): hoe vaak een
gebruiker opnieuw moet authenticeren is waarneembaar gedrag, geen detail.

- [x] Change aanmaken (`openspec new change`), naam in de trant van
      `tune-connector-session`
- [x] Delta-spec op `linny-mcp-oidc`: een requirement dat een gekoppelde client
      bij regelmatig gebruik niet opnieuw hoeft te autoriseren, en dat een
      onthouden toestemming vervalt bij gewijzigde scopes of audience
- [x] `design.md`: de meting van 2026-09-29, waarom de access-token kort blijft,
      en waarom de sessie-cookie er bewust buiten valt


## Summary of Changes

OpenSpec-change `tune-connector-session` aangemaakt en gevalideerd: proposal,
design, tasks (22) en een delta-spec op `linny-mcp-oidc` met vier requirements.

De delta legt vast dat een gekoppelde client bij dagelijks gebruik gekoppeld
blijft, dat de access-token daarbij **niet** verlengd wordt, dat onthouden
toestemming vervalt bij gewijzigde scopes of audience, en dat de browsersessie
er buiten blijft.
