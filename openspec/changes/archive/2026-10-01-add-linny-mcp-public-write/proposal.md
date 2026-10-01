# Proposal

## Why

De publieke Authelia-route naar linny-mcp is nu hard read-only: nginx wisselt het bearer-token
van de client om voor een vast intern token met scope `read:*`. Daardoor kan Claude Mobile/Online
het notitieboek wél lezen maar nooit schrijven, terwijl schrijven alleen via de ssh-tunnel
(Claude Code/Desktop) kan. Nu Authelia met 2FA voor de publieke route bestaat, is een
schrijfbare publieke route verdedigbaar — mits achter een bewuste, omkeerbare schakelaar en een
scherper Authelia-slot dan "iedere 2FA-gebruiker".

## What Changes

- Nieuwe NixOS-optie `services.linny-mcp-host.publicWrite` (bool, default `false`). Bij `false`
  injecteert nginx het bestaande `read:*`-leestoken (huidig gedrag); bij `true` injecteert nginx
  een schrijf-capabel intern token (scope `write:*`). De optie kiest welk nginx-snippet-pad in de
  `include` van de MCP-location komt. Volledig omkeerbaar via `nixos-rebuild switch`.
- Nieuw agenix-secret `secrets/linny-mcp-nginx-write-token.age` (owner `nginx`): een
  nginx-snippet met `proxy_set_header Authorization "Bearer …"` voor het schrijf-capabele interne
  token. Plus een nieuw gehasht tokens-record in `secrets/linny-mcp-tokens.age` voor dat interne
  token met scope `write:*`. Alleen padwaarden in Nix-opties; nooit een tokenliteral in de store.
- Authelia: een benoemde `identity_providers.oidc.authorization_policies.linny-mcp-write`
  (default deny, regel `two_factor` voor `subject = group:admins`), gezet op de
  `claude-connector`-client in plaats van kaal `two_factor`. Sluit het open punt dat élke
  Authelia-gebruiker met 2FA toegang tot het notitieboek krijgt.
- Het tunnel-token `claude-web` gaat van `read:*,write:inbox` naar `read:*,write:*`, zodat
  Claude Code op de laptop (thuis of via WireGuard op het werk; los van de publieke switch) ook
  bestaande, met de hand geschreven notities mag wijzigen. **BREAKING** voor het gedrag van de
  bestaande tunnel-token: de hostile-corpus-quarantaine (alleen eigen `agent-draft`s) vervalt
  voor deze token.

## Capabilities

### New Capabilities
<!-- geen -->

### Modified Capabilities
- `linny-mcp-oidc`: het interne token waarmee nginx namens geauthenticeerde clients bij linny-mcp
  aanklopt is niet langer onvoorwaardelijk leesrechten-alleen, maar door een expliciete,
  default-uit schakelaar te kiezen tussen een lees- en een schrijf-capabel token; en de
  OIDC-client wordt beperkt tot een benoemde authorization policy in plaats van iedere
  2FA-gebruiker.
- `linny-mcp-hosting`: de tunnel-token draagt niet langer `read:*,write:inbox` maar `read:*,write:*`.

## Impact

- `modules/linny-mcp.nix`: nieuwe optie, tweede agenix-secret, snippet-keuze in de `include`.
- `modules/authelia.nix`: nieuwe `authorization_policies`-blok + verwijzing op `claude-connector`.
- `secrets/linny-mcp-tokens.age`: `claude-web` → `write:*`, nieuw intern schrijf-token-record.
- `secrets/linny-mcp-nginx-write-token.age`: nieuw.
- `secrets/secrets.nix`: recipient-regel voor het nieuwe secret.
- Tests: `modules/linny-mcp_test.py` (optie, geen tokenliteral in nginx-config, twee-maal-eval
  met/zonder OIDC), eventueel `modules/linny-mcp-authz/`.
- `docs/linny-mcp.md` + `CLAUDE.md`: route-matrix en de switch documenteren.
- Veiligheid: `write:*` over publiek heft de quarantaine-bescherming op — bewust, gegate achter
  switch + policy + 2FA.
