# Ontwerp: Authelia als OIDC-provider vóór linny-mcp

## Waarom Authelia er eerst níét voor stond

`add-linny-mcp-hosting` zette de MCP-vhost bewust zónder Authelia, met deze redenering: Authelia is
een redirect-gebaseerde browserflow, en een MCP-client stuurt alleen `Authorization: Bearer` en
volgt geen redirect naar HTML.

Die redenering klopt — voor **forward-auth**. Ze gaat niet op voor Authelia's tweede rol.

```
forward-auth (zoals linny.toorren.net)     OIDC-provider (wat we nu doen)
─────────────────────────────────────      ──────────────────────────────
onauthenticated → 302 naar portaal          client haalt een access token
client krijgt HTML, snapt er niets van      client stuurt Bearer authelia_at_…
alleen bruikbaar in een browser             bruikbaar voor elke API-client
```

Authelia kan beide. Dat het bij ons tot nu toe alleen het linker geval deed, zei iets over onze
configuratie, niet over Authelia.

## Bewijs dat dit kan

- Authelia is **OpenID Certified** als provider (Basic/Implicit/Hybrid/Form Post/Config OP).
- Authelia implementeert **OAuth 2.0 Bearer Tokens**; de authz-endpoints (ForwardAuth, ExtAuthz,
  **AuthRequest**) ondersteunen een HeaderAuthorization-strategie met het bearer-schema. De
  AuthRequest-variant is precies wat nginx' `auth_request`-module aanspreekt, op
  `/api/authz/auth-request`.
- De OIDC-provider **draait hier al**: `modules/authelia.nix` heeft een werkende client voor Wallos
  (`identity_providers.oidc.clients`). Een tweede client toevoegen is bekend terrein.
- Claude's connector-dialoog heeft onder *Advanced settings* velden voor een **OAuth client id en
  secret** — vooraf registreren is dus de bedoelde werkwijze.
- Claude Mobile ondersteunt connectors; Gmail en Outlook draaien er op dezelfde manier
  (org-beschikbaar, per gebruiker inloggen).

## De flow

```
Claude Mobile / Online
   │
   │ 1. authorization code flow
   ▼
auth.toorren.net   Authelia als OIDC-provider
   │                 client_id/secret vooraf geregistreerd
   │                 two_factor policy, net als Wallos
   │
   │ 2. Authorization: Bearer authelia_at_…
   ▼
nginx   linny-mcp.toorren.net
   │     auth_request ──► http://127.0.0.1:9091/api/authz/auth-request
   │                       (bearer-schema toegestaan)
   │     200 → door;  401 → weg, mét WWW-Authenticate
   │     Authorization vervangen door het statische linny-mcp-token
   ▼
linny-mcp   127.0.0.1:8096      ongewijzigd
```

## Beslissingen

### 1. Nginx wisselt de header om; linny-mcp blijft ongemoeid

linny-mcp krijgt géén OAuth. `internal/auth/doc.go` vermeldt weliswaar *"An OIDCAuthenticator may be
added later without changing callers"*, maar dat is upstream-werk in een repo die niet van ons is
(`linden-project/linny-mcp-server`). Een eigen tak op een authenticatie-subsysteem onderhouden is
een terugkerende last; deze opzet vermijdt dat volledig. Alles gebeurt in nginx en Authelia.

### 2. Eén identiteit aan de achterkant — bewust geaccepteerd

Omdat nginx één statisch token injecteert, is elke door Authelia toegelaten gebruiker voor linny-mcp
dezelfde. **Authelia bepaalt wie erin mag; linny-mcp kan ze niet uit elkaar houden.** Dat is het
verschil tussen authenticatie en autorisatie, en we nemen het voor lief: zowel het notitieboek als
Authelia hebben één gebruiker. Komt daar ooit een tweede bij, dan is dit het eerste dat opnieuw
bekeken moet worden — per-gebruiker-scopes bestaan pas als die OIDCAuthenticator er is.

### 3. Discovery serveren we onvoorwaardelijk

Het MCP-authspec wil een 401 met `WWW-Authenticate: Bearer resource_metadata="…"` plus een
`/.well-known/oauth-protected-resource`. Of Claude's connector daarop staat of genoegen neemt met
het handmatig ingevulde client id, weten we niet. We serveren het hoe dan ook: een paar regels
statische JSON en één nginx-directive. Zo verdwijnt de onzekerheid in plaats van dat iemand hem
moet uitzoeken.

### 4. Het statische token hoort niet in de nix-store

`proxy_set_header Authorization "Bearer …"` zou het token in `/nix/store/…-nginx.conf` zetten, en
die is wereldleesbaar. Daarom een agenix-secret met een kant-en-klare nginx-snippet die de location
`include`t, eigendom van de nginx-user, 0400. Zelfde patroon als de bestaande linny-mcp-secrets.

### 5. Leesgericht token

De aanleiding is lezen en doorzoeken vanaf de telefoon, niet schrijven. Het token achter nginx krijgt
daarom `read:*`. De scope-grammatica van linny-mcp (`internal/authz/scopes.go`) kent ook
`deny:taxonomy:<naam>:<term>`, en deny stuurt de *zichtbaarheid* — "a doc you cannot read you cannot
act on". Materiaal dat niet in een chat thuishoort kan daarmee werkelijk buiten bereik blijven, niet
bij afspraak maar omdat de index het voor dat token niet teruggeeft. Schrijven blijft voorbehouden
aan de tunnel-clients met hun eigen token.

### 6. Host-header blijft loopback

Ongewijzigd t.o.v. de bestaande vhost: de MCP-SDK zet DNS-rebinding-bescherming automatisch aan voor
een loopback-server en weigert elke niet-loopback `Host` met 403. `recommendedProxySettings = false`
plus `Host localhost` blijft dus staan. Zie `docs/linny-mcp.md`.

## Verworpen alternatieven

### Geheim in de URL

Een nginx-location met een lang random pad dat intern de `Authorization`-header injecteert. Werkt,
kost geen regel code, en past in een URL-only connector. Verworpen: de URL *is* dan het wachtwoord.
Hij belandt in de connector-configuratie, in logs, en intrekken betekent het pad wijzigen. Voor een
notitieboek met klantmateriaal is dat geen slot maar een gordijn. Nu bleek dat de Authelia-route
ongeveer evenveel werk is, verdwijnt ook het laatste argument ervoor.

### Org-connector via de TechNative-admin

Vraagt een admin om een connector te registreren die naar een persoonlijk tweede brein wijst. Zonder
OAuth kent linny-mcp geen onderscheid tussen gebruikers, dus of collega's erbij kunnen hangt volledig
af van hoe fijnmazig de admin de beschikbaarheid kan scopen — een eigenschap van de organisatie, niet
van onze server. Met deze change is het bovendien overbodig: Authelia doet de autorisatie.

### Persoonlijk abonnement

Omzeilt het org-beleid, maar niet het ontbreken van OAuth. Lost dus de verkeerde muur op.

## Open risico

**Authelia heeft geen dynamische clientregistratie** (RFC 7591); de documentatie noemt de
ondersteuning expliciet "None". Of Claude's connectorflow uit de voeten kan met een vooraf
geregistreerde client — wat de velden in *Advanced settings* wel suggereren, en waar upstream MCP
ook naartoe beweegt — is de enige vraag waar dit ontwerp op kan stranden.

Daarom is taak 1.1 een spike: client aanmaken, connector toevoegen, kijken of de flow rondkomt.
Slaagt dat, dan is de rest invulwerk. Zo niet, dan vervalt deze change en blijft de ssh-tunnel de
enige route — en hebben we een avond verloren in plaats van een ontwerp.

Een tweede, kleinere onbekende: de redirect-URI. `https://pivot.claude.ai/auth/gateway-callback`
is de beste aanwijzing die we hebben, maar die komt uit een zoekresultaat en niet uit een
specificatie. Authelia-clients accepteren meerdere redirect-URI's, dus bijstellen is goedkoop zodra
de dialoog de echte toont.
