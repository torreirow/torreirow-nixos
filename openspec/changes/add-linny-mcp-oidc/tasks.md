## 1. Spike: werkt de connectorflow tegen Authelia?

> Deze sectie beslist of de rest zin heeft. Niets anders beginnen voordat 1.4 groen is.

- [x] 1.1 OIDC-client `claude-connector` in Authelia registreren (handmatig/tijdelijk, nog niet
      declaratief): `authorization_code`, `response_types = [ code ]`, scopes `openid profile email`,
      `authorization_policy = two_factor`, redirect-URI `https://pivot.claude.ai/auth/gateway-callback`
- [x] 1.2 Het bearer-schema toestaan op het `auth-request`-authz-endpoint en met `curl` bewijzen dat
      een `authelia_at_…` token 200 krijgt en een onzinnig token 401 — nog zonder linny-mcp erachter
- [x] 1.3 `linny-mcp.toorren.net` publiek zetten met `auth_request` ervoor
- [ ] 1.4 **Beslispunt:** connector toevoegen in Claude en de flow doorlopen. Komt de authorization
      code rond zonder dynamische clientregistratie? Noteer de werkelijke redirect-URI die de
      dialoog toont
- [ ] 1.5 Strandt 1.4: bevindingen vastleggen in `design.md`, change intrekken, tunnel blijft

## 2. Declaratief maken

- [x] 2.1 De client uit 1.1 in `modules/authelia.nix` zetten, naast de Wallos-client
- [x] 2.2 GEEN client secret nodig: publieke client met PKCE S256. Scheelt een argon2-hash
      in een publieke repo. Claude's dialoog vraagt er optioneel om; leeg laten
- [x] 2.3 Authz-endpoint met bearer-schema declaratief in `modules/authelia.nix`
- [x] 2.4 Regressie: `linny.toorren.net` en de andere Authelia-vhosts nog steeds een redirect naar
      het portaal, niet een 401 — de authz-wijziging raakt ze allemaal

## 3. Nginx-kant in modules/linny-mcp.nix

- [x] 3.1 Optie `oidc.enable` + `oidc.authzEndpoint`; `publicEndpoint` weer aan op malandro
- [x] 3.2 `auth_request` vóór de proxy; `Host localhost` en de SSE-instellingen ongewijzigd laten
- [x] 3.3 Statisch linny-mcp-token via agenix-snippet die nginx `include`t — **niet** als
      `proxy_set_header` in de nix-store
- [x] 3.4 `/.well-known/oauth-protected-resource` serveren (statische JSON, wijst naar Authelia)
- [x] 3.5 `WWW-Authenticate: Bearer resource_metadata="…"` op de 401 van `auth_request`
- [x] 3.6 Leesgericht token genereren (`read:*`, eventueel `deny:taxonomy:…`) en in
      `secrets/linny-mcp-tokens.age` opnemen; het schrijfbare token van de tunnel blijft bestaan

## 4. Toetsen

- [x] 4.1 `modules/linny-mcp_test.py` uitbreiden: `auth_request` aanwezig, well-known-location
      aanwezig, géén tokenliteral in de nginx-config, `Host localhost` nog intact
- [ ] 4.2 Live: `/mcp` zonder token 401 mét `WWW-Authenticate`; met een geldig Authelia-token 200
- [ ] 4.3 Live: een ingetrokken/verlopen token krijgt 401
- [ ] 4.4 Live vanaf de telefoon: notities doorzoeken via de connector
- [ ] 4.5 Bewijzen dat het leestoken niet kan schrijven (`create_doc` → geweigerd)
- [ ] 4.6 De ssh-tunnel werkt onveranderd naast de publieke route

## 5. Documentatie

- [ ] 5.1 `docs/linny-mcp.md`: de OIDC-flow, waarom forward-auth niet werkte en de OIDC-rol wel,
      en het onderscheid authenticatie (Authelia) versus autorisatie (één token)
- [ ] 5.2 `CHANGELOG.md` onder `## NEXT VERSION`
- [ ] 5.3 Tokenrotatie bijwerken: er zijn nu twee soorten geheimen (Authelia-client secret en het
      interne linny-mcp-token)
