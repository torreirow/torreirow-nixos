# Design

## Context

Zie `proposal.md` — Why. De read-only-ness van de publieke route zit in één nginx-regel in
`modules/linny-mcp.nix`: `include ${cfg.oidc.tokenSnippet}*;` injecteert een vast intern bearer-token
op `/mcp` nadat `auth_request` het Authelia-token heeft gevalideerd. Dat interne token
(`linny-mcp-nginx-token.age`) draagt `read:*`. linny-mcp leest zijn tokens-records éénmalig bij
start; een `restartTrigger` op het ciphertext-pad dwingt herlezen af bij hercodering.

Belangrijke bestaande valkuilen die het ontwerp respecteert:
- Opties staan wereldleesbaar in de nix-store → alleen **paden** als optie-waarde, nooit een
  tokenliteral. Het snippet is daarom een agenix-bestand met de volledige `proxy_set_header`.
- De `include`-mask eindigt bewust op `*` zodat de nginx-config in de build-sandbox valideert
  (waar `/run/agenix` niet bestaat) en dicht faalt als het bestand op de host ontbreekt.
- `modules/linny-mcp_test.py` evalueert de config twee keer (met én zonder OIDC), omdat `//` in
  Nix een ondiepe merge is en een fout in de OIDC-laag anders onzichtbaar blijft.

## Goals / Non-Goals

**Goals:**
- Eén omkeerbare schakelaar die de publieke route tussen read-only en read+write zet, zonder de
  tunnel te raken.
- De publieke schrijfroute scherper afgrenzen dan "iedere 2FA-gebruiker".
- De tunnel-token (`claude-web`) volledige schrijfrechten geven.

**Non-Goals:**
- De tunnel-architectuur wijzigen (blijft read+write, los van de switch).
- `claude-mobile` aanpassen — dat record wordt door geen enkele actieve route gebruikt (de publieke
  route gebruikt het interne nginx-token, niet een client-record). Blijft ongemoeid.
- Een per-request keuze tussen lezen en schrijven op de publieke route. De switch is host-breed en
  declaratief; fijnmaziger dan dat is buiten scope.

## Decisions

### 1. Schakelaar = `services.linny-mcp-host.publicWrite`, die het snippet-pad kiest

De optie (bool, default `false`) selecteert welk agenix-snippet in de `include` komt:
`cfg.oidc.tokenSnippet` (lezen) of een nieuw `cfg.oidc.writeTokenSnippet` (schrijven). Alléén het
gekozen snippet wordt als agenix-secret gedeclareerd en in de `include` gezet.

Alternatief (verworpen): één intern token houden en zijn scope in het tokens-record omzetten. Dat
is geen declaratieve Nix-schakelaar — het vergt een secret-edit en laat zich niet per `switch`
aan/uit zetten of A/B-testen. Twee snippets + een bool is zuiver declaratief en omkeerbaar.

Alternatief (verworpen): nginx laten kiezen op een runtime-variabele. `include` is statisch in
nginx; een `map`/`if` rond `proxy_set_header Authorization` is broos en lekt snel de verkeerde
header. De build-tijd-keuze is eenvoudiger en even krachtig voor een host-brede schakelaar.

### 2. Tweede intern token met scope `write:*`, als los record + los snippet

`secrets/linny-mcp-nginx-write-token.age` bevat het `proxy_set_header`-snippet met een eigen
bearer-waarde; dat bearer heeft een eigen gehasht record in `secrets/linny-mcp-tokens.age` met
scope `write:*`. Zo blijven lees- en schrijftoken volledig gescheiden: de switch terugzetten
ontneemt de publieke route onmiddellijk alle schrijfrechten, zonder dat er een token geroteerd hoeft
te worden.

De nieuwe agenix-secret-declaratie staat achter `mkIf (cfg.oidc.enable && cfg.publicWrite)`, zodat
het leestoken-secret en het schrijftoken-secret elkaar nooit allebei claimen op hetzelfde pad.

### 3. Authelia: benoemde `authorization_policies.linny-mcp-write`

```nix
identity_providers.oidc.authorization_policies.linny-mcp-write = {
  default_policy = "deny";
  rules = [ { policy = "two_factor"; subject = [ "group:admins" ]; } ];
};
# op de claude-connector client:
authorization_policy = "linny-mcp-write";   # i.p.v. kaal "two_factor"
```

Dit sluit het open punt dat élke Authelia-gebruiker met 2FA een connector-token krijgt. Met één
gebruiker is het vandaag functioneel gelijk aan `two_factor`, maar het is de plek waar een tweede
gebruiker buiten `admins` wordt tegengehouden — en dat is precies relevant zodra schrijven open gaat.

De policy wordt **onvoorwaardelijk** gezet (niet alleen bij `publicWrite`): een scherper slot op de
connector schaadt de read-only-stand niet en vermijdt een stille versoepeling bij het terugzetten
van de switch.

### 4. `claude-web` → `read:*,write:*`

Puur een scope-wijziging in het tokens-record. De tunnel wisselt geen token om, dus dit raakt
alleen Claude Code/Desktop. De `restartTrigger` op het ciphertext-pad zorgt dat linny-mcp de nieuwe
scope leest na de hercodering.

## Risks / Trade-offs

- **`write:*` over publiek heft de hostile-corpus-quarantaine op** (agent mag bestaande notities
  wijzigen) → gemitigeerd doordat het (a) default uit staat, (b) achter 2FA + `group:admins` zit,
  en (c) met één `switch` terug te draaien is. Bewuste, gedocumenteerde trade-off.
- **Twee snippets die hetzelfde pad zouden kunnen claimen** → gemitigeerd met wederzijds
  uitsluitende `mkIf`-condities; de config-test controleert dat in beide standen precies één
  `Authorization`-snippet in de `include` staat.
- **Stille versoepeling bij terugzetten** → de switch verwisselt alleen het token; de Authelia-policy
  blijft staan. De test dekt dat `publicWrite = false` weer naar het leestoken wijst.
- **Een gelekt schrijftoken is gevaarlijker dan een leestoken** → zelfde agenix-/ownership-regime
  als het leestoken (`owner = nginx`, `mode 0400`, nooit in de store); rotatie is één hercodering.

## Migration Plan

1. Secrets eerst: `claude-web` → `write:*` en het nieuwe interne schrijf-token-record toevoegen in
   `linny-mcp-tokens.age` (via stdin, zie onder); `linny-mcp-nginx-write-token.age` aanmaken;
   recipient-regel in `secrets/secrets.nix`.
2. `modules/linny-mcp.nix` + `modules/authelia.nix` aanpassen; tests bijwerken.
3. `nixos-rebuild switch --flake .#malandro` met `publicWrite = false` → verifieer dat de publieke
   route nog read-only is en de tunnel nu `write:*` heeft.
4. Testvenster: `publicWrite = true` → mobiel/Online schrijven proberen → daarna terug op `false`.

**Secrets schrijven gaat via stdin**, niet via `$EDITOR` (agenix overschrijft `$EDITOR` met
`cp -- /dev/stdin` zodra stdin niet-interactief is → een eigen editor levert stil een lege payload):

```bash
cd secrets && ragenx -e linny-mcp-tokens.age < records.jsonl
```

**Rollback**: `publicWrite = false` + `switch` → publieke route direct weer read-only. Het
schrijftoken-secret en -record kunnen blijven staan (worden dan niet geïncludeerd) of worden
verwijderd.

## Open Questions

- Geen die de specs, de aanpak of de taken veranderen. De `subject` (`group:admins` vs
  `user:wouter`) is een vrije keuze binnen de policy; `group:admins` is gekozen omdat het met
  toekomstige beheerders meeschaalt.
