## Why

Het torrlinny-notitieboek (122 markdown-notities) is vandaag alleen leesbaar voor mensen: Hugo
bouwt er een statische site van op `linny.toorren.net` achter Authelia. Er is geen manier om de
notities vanuit Claude te doorzoeken, en al helemaal niet om er iets aan toe te voegen.

Deze change zet daar een tweede, agent-gerichte ontsluiting naast — lezen én schrijven — via
`linny-mcp` (een MCP-server) op malandro, bereikbaar voor Claude Online en Mobile. De bestaande
Hugo-site blijft ongemoeid.

Zie Beans-epic `nixos-m0vn` voor de volledige afweging.

## What Changes

- Nieuwe flake-input `linny-mcp` (`github:linden-project/linny-mcp-server`, v0.2.0) met zijn
  NixOS-module en overlay, aangesloten op malandro.
- Nieuwe module `modules/linny-mcp.nix` — een wrapper rond `services.linny-mcp` die het
  malandro-specifieke toevoegt: een **eigen corpus-clone**, bidirectionele git-sync, de indexer,
  de agenix-secrets en de publieke vhost.
- **Eigen werkmap** `/var/lib/linny-mcp/corpus`, strikt gescheiden van `/var/lib/torrlinny/checkout`.
  Die laatste is van `linny-web-build` en wordt elke 3 minuten met `reset --hard` + `clean -fdx`
  behandeld; agent-schrijfacties zijn untracked tot git-sync ze commit en zouden daar stil sneuvelen.
- Bidirectionele `git-sync` (timer, 30 s) met een **read/write** deploy key, los van de bestaande
  read-only sleutel van de Hugo-build. GitHub blijft het knooppunt.
- `lindexer build` (ExecStartPre) + `lindexer watch` (ExecStart) in een eigen unit, geordend vóór
  `linny-mcp.service` — `serve` bouwt zelf nooit een index en herindexeert alleen zijn eigen writes.
- Bearer-tokens uit agenix, per client (`claude-web`, `claude-mobile`), scope `read:*,write:inbox`.
  Plus een `restartTrigger` op het ciphertext-pad, want de server leest het tokenbestand eenmalig.
- Publieke vhost `linny-mcp.toorren.net` op het bestaande wildcard-cert, **zonder Authelia**
  (een MCP-client volgt geen loginredirect) en SSE-veilig geproxied.
- `PORTS.md` bijgewerkt.

## Capabilities

### Added Capabilities
- `linny-mcp-hosting`: het torrlinny-corpus schrijfbaar serveren aan MCP-clients over HTTPS, met
  bearer-auth, quarantaine op agent-writes, een corpus dat los staat van de Hugo-build, en een
  index die vóór het serveren bestaat en daarna meeloopt.

## Impact

- `flake.nix` — input + overlay + module in de malandro-lijst.
- `modules/linny-mcp.nix` — nieuw.
- `hosts/malandro/configuration.nix` — import + `services.linny-mcp-host.enable`.
- `secrets/secrets.nix`, `secrets/linny-mcp-deploy-key.age`, `secrets/linny-mcp-tokens.age` —
  reeds aanwezig (voorbereid buiten deze change om).
- `PORTS.md`, `docs/linny-mcp.md`, `CLAUDE.md`, `CHANGELOG.md`.
- Geen wijziging aan `modules/torrlinny.nix` of de gedeelde `linny-web`-module.
