## Why

`add-linny-mcp-hosting` heeft linny-mcp werkend op malandro, maar de oorspronkelijke bedoeling —
het notitieboek doorzoeken vanaf Claude Mobile — is niet gehaald. Het publieke endpoint is
inmiddels uitgezet (`publicEndpoint = false`); lokale clients gaan via een ssh-tunnel.

Twee muren staan in de weg, en ze zijn andere muren dan we dachten:

1. **De organisatie laat gebruikers geen custom connectors aanmaken.** Een owner kan er één
   *beschikbaar* maken, maar er is geen gedeeld credential: elke gebruiker authenticeert
   individueel via de identity provider.
2. **linny-mcp kent geen OAuth.** `internal/auth` doet uitsluitend statische bearer-tokens en
   antwoordt met een kale 401 zonder `WWW-Authenticate` — precies de header waarmee een MCP-client
   ontdekt wáár hij moet authenticeren. De connector-dialoog heeft geen veld voor een token, alleen
   voor een URL en optioneel een OAuth client id/secret.

De tweede muur is de echte: ook een persoonlijk abonnement lost hem niet op.

Deze change zet Authelia ertussen als **OpenID Connect-provider**, zodat de connector dezelfde
vorm krijgt als de Gmail- en Outlook-connectors: per gebruiker inloggen, met tweede factor,
intrekbaar. linny-mcp zelf blijft ongewijzigd achter de loopback op zijn statische token.

## What Changes

- **Authelia**: extra OIDC-client voor de Claude-connector in `modules/authelia.nix`
  (naast de bestaande Wallos-client). Client secret via agenix, niet in de nix-store.
- **Authelia**: het `auth-request`-authz-endpoint krijgt het **bearer**-schema toegestaan, zodat
  een API-client geen browserredirect hoeft te volgen.
- **`modules/linny-mcp.nix`**: `publicEndpoint` weer aan, maar nu met `auth_request` naar Authelia
  vóór de proxy. Nginx vervangt de inkomende `Authorization`-header door het statische
  linny-mcp-token, via een agenix-bestand dat nginx `include`t.
- **Discovery**: nginx serveert `/.well-known/oauth-protected-resource` en zet
  `WWW-Authenticate: Bearer resource_metadata="…"` op een 401 — onvoorwaardelijk, ook als blijkt
  dat Claude er niet om vraagt.
- **Token-scope**: het linny-mcp-token achter nginx wordt leesgericht (`read:*`), eventueel met
  `deny:taxonomy:…` voor materiaal dat niet in een chat hoort. Schrijven blijft aan de
  tunnel-clients.
- `docs/linny-mcp.md` en `CHANGELOG.md` bijwerken.

## Impact

- Raakt `modules/authelia.nix` — dat fronts ook Nextcloud, Grafana en de andere vhosts. Een fout
  in de authz-configuratie treft méér dan linny-mcp; de eerste taak toetst daarom in isolatie.
- Vereist dat `linny-mcp.toorren.net` weer publiek bereikbaar is. Dat is nu bewust dicht.
- Eén open risico, zie `design.md`: Authelia heeft geen dynamische clientregistratie. Taak 1.1
  beantwoordt of Claude daarzonder uit de voeten kan; valt dat verkeerd uit, dan vervalt deze
  change en blijft de tunnel de enige route.
