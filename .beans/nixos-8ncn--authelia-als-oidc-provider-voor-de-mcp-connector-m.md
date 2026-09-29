---
# nixos-8ncn
title: Authelia als OIDC-provider voor de MCP-connector (mobiel)
status: completed
type: feature
priority: normal
created_at: 2026-09-25T20:08:34Z
updated_at: 2026-09-27T16:37:52Z
parent: nixos-m0vn
---

De mobiele route uit deze epic is niet gehaald. Deze bean maakt hem alsnog
mogelijk door Authelia als OpenID Connect-provider vóór linny-mcp te zetten.

OpenSpec-change: `add-linny-mcp-oidc` (proposal, design, tasks, spec).

## Waarom het strandde

Niet op het org-beleid, maar op het auth-model — dat onderscheid is de kern:

- De connector-dialoog heeft alleen een URL-veld en optioneel OAuth client
  id/secret. **Er is geen veld voor een bearer-token.**
- linny-mcp kent geen OAuth: `internal/auth` doet uitsluitend statische tokens
  en antwoordt met een kale 401 zonder `WWW-Authenticate` — juist de header
  waarmee een MCP-client ontdekt waar hij moet authenticeren.
- Een org-owner maakt een connector alleen *beschikbaar*; elke gebruiker
  authenticeert individueel via de identity provider. Er is geen gedeeld
  credential dat alle seats binnenlaat.

Daarom lost ook een persoonlijk abonnement het niet op: dat omzeilt het
org-beleid, niet het ontbreken van OAuth.

## De oplossing

Authelia draait hier al als OIDC-provider (er staat een werkende client voor
Wallos in modules/authelia.nix) en ondersteunt OAuth 2.0 bearer-tokens op zijn
authz-endpoints. Nginx valideert met `auth_request` tegen
`/api/authz/auth-request` en wisselt de header om voor het interne token.

    Claude Mobile → Authelia (OIDC) → nginx auth_request → linny-mcp (loopback)

Dat de vhost eerder bewust zónder Authelia stond, klopte: forward-auth is een
browserredirect en een MCP-client volgt geen redirect naar HTML. Dat geldt voor
forward-auth, niet voor de OIDC-rol. Authelia kan beide.

## Beslispunt vóór alles

Authelia heeft **geen dynamische clientregistratie** (documentatie: "None").
Of Claude's flow uit de voeten kan met een vooraf geregistreerde client is de
enige aanname waarop dit ontwerp kan omvallen. Taak 1.4 van de change toetst
dat als eerste. Valt het verkeerd uit, dan vervalt de change en blijft de
ssh-tunnel de enige route — kosten: een avond, geen half afgebouwde authlaag.

## Aandachtspunten

- De wijziging aan het authz-endpoint zit in modules/authelia.nix en raakt
  daarmee álle Authelia-vhosts. Regressie: die moeten nog steeds een redirect
  naar het portaal krijgen, geen 401.
- Eén identiteit aan de achterkant: nginx injecteert één statisch token, dus
  Authelia bepaalt wie erin mag en linny-mcp kan gebruikers niet onderscheiden.
  Bewust geaccepteerd — één gebruiker. Eerste ding dat herzien moet worden als
  er een tweede bijkomt.
- Het publieke pad wordt leesgericht (`read:*`, eventueel `deny:taxonomy:…`).
  Schrijven blijft bij de tunnel-clients.
- Het interne token mag niet in de nix-store: via een agenix-snippet die nginx
  `include`t, niet als `proxy_set_header` in de config.

## Afgerond 2026-09-27

Werkt live. De connector `LinnyTRW` staat in Claude en doorloopt een echte
OAuth-flow tegen Authelia met tweede factor.

**Het ontwerp is onderweg gewijzigd.** Authelia's eigen authz-endpoint bleek
onbruikbaar: dat accepteert alleen de scope `authelia.bearer.authz`, en bij die
scope eist Authelia verplicht PAR. Claude doet geen PAR — ook niet nadat de
discovery-metadata het als verplicht adverteerde; Wallos brak daar wél op, want
die vlag geldt server-breed. Teruggedraaid.

Oplossing: de scope laten vallen, waarmee de eis vervalt, en een eigen dienst
`linny-mcp-authz` (stdlib-Python, 20 tests) die het token bij Authelia's
introspection-endpoint toetst. Nginx kan dat niet zelf — introspection antwoordt
met 200 en `{"active": false}` voor een ongeldig token, dus de body moet gelezen.

Vier dingen die alleen te meten waren, alle vier uit het nginx-access.log:
- redirect-URI is `https://claude.ai/api/mcp/auth_callback`, niet wat de
  documentatie suggereerde
- Claude stuurt `resource=` (RFC 8707) → moet als `audience` op de client
- Authelia legt per client één introspection-auth-methode vast (`basic`)
- bij loopback weigert Authelia met `invalid X-Forwarded-Proto header value 'http'`

**Eén zelf veroorzaakte storing:** `server.endpoints.authz` vervángt de
standaardset in plaats van hem aan te vullen. Met alleen het nieuwe endpoint
verdween `/api/verify` en gaven álle Authelia-vhosts een 500. Vier minuten.
`legacy` staat nu expliciet naast het nieuwe endpoint, met die meting in de code.

**Prestatie:** introspection kostte 164 ms, waarvan 163 ms de argon2-verificatie
van het clientgeheim. Die kosten beschermen zwakke wachtwoorden; dit geheim is 72
willekeurige tekens. Met goedkopere parameters nu 29 ms, en daarmee kon de cache
van 60 naar 5 seconden — dat is het venster waarin een ingetrokken token nog werkt.

Bewijs in `modules/linny-mcp-authz/verify-live.sh` (15 controles). De scherpste:
een echt, door Authelia als `active` bevestigd token van een ándere client krijgt
401. Zonder die client_id-controle zou elk geldig token op deze Authelia het
notitieboek openen.

OpenSpec-change gearchiveerd als `2026-09-27-add-linny-mcp-oidc`.
