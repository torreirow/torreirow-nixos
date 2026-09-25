---
# nixos-ero6
title: bearer-tokens met read:*,write:inbox via agenix (+ restartTrigger)
status: completed
type: task
priority: normal
created_at: 2026-09-25T07:44:52Z
updated_at: 2026-09-25T11:30:45Z
parent: nixos-m0vn
blocked_by:
    - nixos-dqs2
---

Bearer-tokens met de juiste scopes, uit agenix, zonder dat er ooit een tokenliteral in een
Nix-optie of in `/nix/store` belandt.

## Scopes — dit is optie A uit de epic
Per client een eigen token met **`read:*,write:inbox`**. Niet `write:*`.

`write:inbox` laat de agent nieuwe documenten maken (die krijgen `status: agent-draft`) en alleen
zijn eigen nog-niet-gepromoveerde drafts bijwerken. Bestaande, met de hand geschreven notities
zijn onaanraakbaar:

    // write:* always allows; write:inbox allows only quarantined (agent-draft) docs.

`gen-token` heeft `read:*` als default — schrijven moet je er altijd bewust bij zetten.

Eén token per client (`claude-web`, `claude-mobile`) zodat je er één kunt intrekken zonder de
andere te raken. Het token is het enige slot op het volledige notitieboek, klantmateriaal
inbegrepen, dus behandel het navenant.

## Valkuil: restartTriggers
De server leest het tokenbestand **eenmalig bij start** en herlaadt het nooit. Hercodeer je het
agenix-secret, dan blijft de unitdefinitie byte-identiek en houdt een `switch` de oude scopes in
geheugen. Trigger daarom op het ciphertext-store-pad:

    systemd.services.linny-mcp.restartTriggers = [ config.age.secrets."linny-mcp-tokens".file ];

## Todo
- [x] `nix run github:linden-project/linny-mcp-server -- gen-token --name claude-web --scopes 'read:*,write:inbox'`
- [x] idem `--name claude-mobile`
- [x] gehashte records in `secrets/linny-mcp-tokens.age`; recipients in `secrets/secrets.nix`;
      owner = service-user, mode 0400
- [x] de one-time secrets in Vaultwarden (niet in git, niet in een bean)
- [x] `tokensFile` in de module wijst naar `config.age.secrets."linny-mcp-tokens".path`
- [x] `restartTriggers` op het `.file`-pad
- [x] verifieer: geen tokenliteral in `/nix/store` (`grep -r` op een fragment) en niet in `ps`
- [x] verifieer: request zonder token -> geweigerd; `/healthz` blijft zonder auth bereikbaar
- [x] documenteer hoe je een token rouleert (hercoderen -> switch -> unit herstart via trigger)

## Summary of Changes

Twee records (`claude-web`, `claude-mobile`), beide `read:*,write:inbox`, in
`secrets/linny-mcp-tokens.age`. `tokensFile` wijst naar het agenix-pad; `restartTriggers` op het
ciphertext-pad, want de server leest het tokenbestand eenmalig bij start.

Valkuil vastgelegd: secrets schrijven gaat via **stdin** (`ragenx -e FILE < plaintext`). Agenix
overschrijft een zelfgekozen `$EDITOR` met `cp -- /dev/stdin` zodra stdin niet interactief is
(0.15.0 regel 167), wat stil een lege payload oplevert.
