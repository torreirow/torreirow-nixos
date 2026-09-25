---
# nixos-dqs2
title: 'linny-mcp op malandro: flake-input, module en eigen corpus-clone'
status: completed
type: task
priority: normal
created_at: 2026-09-25T07:44:20Z
updated_at: 2026-09-25T11:30:45Z
parent: nixos-m0vn
---

De upstream-module en -overlay binnenhalen en `services.linny-mcp` op malandro opzetten, met een
**eigen corpus-clone** die losstaat van de Hugo-checkout.

## Kern: niet de bestaande checkout hergebruiken
`/var/lib/torrlinny/checkout` is van `linny-web-build.service` en wordt elke ~3 min behandeld met
`git reset --hard origin/main` + `git clean -fdx`. Agent-schrijfacties zijn untracked tot git-sync
ze commit; `clean -fdx` wist ze dan stil. linny-mcp krijgt daarom `/var/lib/linny-mcp/corpus`.
Zie de epic voor de volledige redenering.

## Harde randvoorwaarden uit de broncode
- Corpus en stateDir **buiten `/home`**: de unit zet `ProtectHome = true`.
- `listenAddress` moet een privé-IP zijn; `internal/config/bind.go` weigert publieke IP's en
  `0.0.0.0`. Loopback mag ook — nginx draait op dezelfde host, dus `127.0.0.1` volstaat hier
  (mipmip bindt zijn mesh-IP omdat zijn proxy op een ándere host staat).
- De stateDir-subdir moet bestaan vóór start: `ReadWritePaths` bind-mount hem, een ontbrekend pad
  faalt met 226/NAMESPACE nog voor exec.

## Todo
- [x] flake-input `linny-mcp.url = "github:linden-project/linny-mcp-server"` + `inputs.nixpkgs.follows`
- [x] nieuwe module `modules/linny-mcp.nix`, geimporteerd in `hosts/malandro/configuration.nix`
- [x] `imports = [ inputs.linny-mcp.nixosModules.linny-mcp ]` + `nixpkgs.overlays = [ inputs.linny-mcp.overlays.default ]`
- [x] `services.linny-mcp`: `enable`, `listenAddress` (privé), `port` (vrije poort — check `PORTS.md`!),
      `publicHostname = "linny-mcp.toorren.net"`, `corpusPath = "/var/lib/linny-mcp/corpus"`,
      `stateDir = "/var/lib/linny-mcp/state"`, `quarantine = true`, `readOnly = false`
- [x] `systemd.tmpfiles.rules` voor corpus + state, eigendom van de service-user
- [x] `PORTS.md` bijwerken met de gekozen poort
- [x] `nix eval` op malandro: paden onder `/var/lib`, bind-adres privé

## Summary of Changes

Flake-input `linny-mcp` (v0.2.0, rev ee628a0) + overlay + upstream NixOS-module op malandro.
`modules/linny-mcp.nix` als wrapper (`services.linny-mcp-host`), corpus op `/var/lib/linny-mcp/corpus`
-- bewust NIET de torrlinny-checkout. Bindt `127.0.0.1:8096` (loopback volstaat: nginx staat op
dezelfde host). PORTS.md bijgewerkt. Pakket bouwt: beide binaries v0.2.0, Go-tests draaien mee
(`doCheck = true`).
