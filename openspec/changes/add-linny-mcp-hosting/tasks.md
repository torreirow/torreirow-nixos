## 1. Flake en module

- [x] 1.1 Flake-input `linny-mcp` (`github:linden-project/linny-mcp-server`) met `nixpkgs.follows`
- [x] 1.2 Overlay + upstream NixOS-module aansluiten op malandro
- [x] 1.3 `modules/linny-mcp.nix`: wrapper met opties `enable`, `domain`, `port`, `corpusDir`
- [x] 1.4 `services.linny-mcp` configureren: loopback-bind, eigen corpus, quarantine aan, schrijfbaar
- [x] 1.5 `systemd.tmpfiles.rules` voor corpus + state (moeten bestaan vóór start; ReadWritePaths
      bind-mount ze, een ontbrekend pad faalt met 226/NAMESPACE)
- [x] 1.6 Import in `hosts/malandro/configuration.nix` + enable
- [x] 1.7 `PORTS.md` bijwerken

## 2. Secrets

- [x] 2.1 `age.secrets` voor deploy key en tokens, eigendom van de service-gebruiker, mode 0400
- [x] 2.2 `tokensFile` naar het agenix-pad
- [x] 2.3 `restartTriggers` op het ciphertext-pad van het tokens-secret

## 3. Corpus en git-sync

- [x] 3.1 Bootstrap-clone-unit (oneshot, `RemainAfterExit`, vóór linny-mcp)
- [x] 3.2 `git-sync`-unit als de service-gebruiker, met `GIT_SSH_COMMAND` en een eigen known_hosts
      buiten de working tree
- [x] 3.3 `branch.<b>.sync` + `syncNewFiles` zetten (git-sync weigert een niet-opgegeven branch;
      agent-writes zijn untracked)
- [x] 3.4 Timer, 30 s
- [x] 3.5 Verifiëren dat `/var/lib/torrlinny/checkout` niet geraakt wordt (statisch bewezen in `modules/linny-mcp_test.py`; live-bevestiging hoort bij 6.x)

## 4. Indexer

- [x] 4.1 `linny-mcp-index`-unit: `ExecStartPre` = `lindexer build`, `ExecStart` = `lindexer watch`
- [x] 4.2 Ordening: na de clone, vóór `linny-mcp.service`
- [x] 4.3 Index-uitvoer naar de state-dir, niet in het corpus

## 5. Vhost

- [x] 5.1 Vhost `linny-mcp.toorren.net` op het wildcard-cert, zonder Authelia
- [x] 5.2 SSE-veilige proxy-config (buffering uit, HTTP/1.1, lange timeouts)

## 6. Verificatie

- [x] 6.1 `nix eval` / `dry-build` van malandro slaagt
- [x] 6.2 Modultest die de opgebouwde config toetst (bind-adres, paden, scheiding van de
      Hugo-checkout, geen Authelia op de vhost, ordening van de units)
- [ ] 6.3 `nixos-rebuild switch` op malandro — **door de gebruiker**
- [ ] 6.4 Live: `/healthz` 200 zonder auth, `/mcp` zonder token geweigerd
- [ ] 6.5 Live: agent-write krijgt `status: agent-draft` en staat binnen ~1 min op GitHub
- [ ] 6.6 Live: write op een bestaande notitie wordt geweigerd
- [ ] 6.7 Live: elders bewerkte notitie wordt doorzoekbaar via MCP
- [ ] 6.8 Live: connectors in Claude Online + Mobile

## 7. Documentatie

- [x] 7.1 `docs/linny-mcp.md`
- [x] 7.2 Verwijzing in `CLAUDE.md`
- [x] 7.3 `CHANGELOG.md` onder `## NEXT VERSION`
