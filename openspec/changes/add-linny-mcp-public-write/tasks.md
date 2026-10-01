# Tasks

## 1. Secrets: tokenscopes en het schrijf-snippet

- [x] 1.1 In `secrets/linny-mcp-tokens.age`: `claude-web` naar scope `read:*,write:*` zetten en een
  nieuw gehasht record toevoegen voor het interne schrijf-token (scope `write:*`, eigen naam bv.
  `nginx-write`). Decrypt → bewerk `records.jsonl` → `cd secrets && ragenx -e linny-mcp-tokens.age
  < records.jsonl` (stdin, niet `$EDITOR`). Verifieer met `ragenx -d` dat alle records aanwezig zijn
  en de scopes kloppen.
- [x] 1.2 `secrets/linny-mcp-nginx-write-token.age` aanmaken: een nginx-snippet
  `proxy_set_header Authorization "Bearer <schrijf-token>";` met het bearer uit 1.1. Genereer het
  one-time token met `linny-mcp gen-token --name nginx-write --scopes 'write:*'` (het gehashte deel
  hoort bij 1.1). Verifieer met `ragenx -d` dat het snippet de juiste `proxy_set_header`-regel bevat.
- [x] 1.3 Recipient-regel voor `secrets/linny-mcp-nginx-write-token.age` toevoegen in
  `secrets/secrets.nix` (zelfde recipients als `linny-mcp-nginx-token.age`). Verifieer dat
  `ragenx -e` zonder "no rule"-fout werkt.

## 2. Module: de schakelaar in linny-mcp.nix

- [x] 2.1 Optie `services.linny-mcp-host.publicWrite` toevoegen (bool, default `false`) met
  mkOption-beschrijving die de trade-off (`write:*` heft quarantaine op; gegate achter switch +
  policy + 2FA) documenteert. Verifieer met `nix eval` dat de optie bestaat en default `false` is.
- [x] 2.2 Nieuwe optie `cfg.oidc.writeTokenSnippet` (pad, default
  `/run/agenix/linny-mcp-nginx-write-token`) en agenix-secret-declaratie voor
  `linny-mcp-nginx-write-token.age` achter `mkIf (cfg.oidc.enable && cfg.publicWrite)`, owner
  `nginx`, mode `0400`, path = die optie.
- [x] 2.3 In de `/`-location de `include` laten verwijzen naar
  `cfg.oidc.writeTokenSnippet` als `cfg.publicWrite`, anders `cfg.oidc.tokenSnippet` — precies één
  `include` in beide standen. Verifieer na `nixos-rebuild build .#malandro` dat de gegenereerde
  nginx-config in stand `false` naar het lees-pad wijst en in stand `true` naar het schrijf-pad, en
  in geen van beide een tokenliteral bevat.

## 3. Authelia: benoemde autorisatiepolicy

- [x] 3.1 In `modules/authelia.nix` het blok
  `identity_providers.oidc.authorization_policies.linny-mcp-write` toevoegen (default_policy
  `deny`, regel `two_factor` voor `subject = [ "group:admins" ]`).
- [x] 3.2 Op de `claude-connector`-client `authorization_policy = "linny-mcp-write"` zetten i.p.v.
  kaal `"two_factor"`; commentaar bijwerken. Verifieer met `nixos-rebuild build .#malandro` dat de
  gegenereerde Authelia-config de policy en de verwijzing bevat.

## 4. Tests

- [x] 4.1 `modules/linny-mcp_test.py` uitbreiden: evalueer de config nu ook met `publicWrite = true`
  (naast de bestaande met/zonder-OIDC-varianten); assert dat de `include` het juiste snippet-pad per
  stand kiest, dat er precies één `Authorization`-snippet is, en dat géén tokenliteral in de
  nginx-config staat. Draai `python3 modules/linny-mcp_test.py` groen.
- [x] 4.2 Waar van toepassing `modules/linny-mcp-authz/` meenemen (de validator verandert niet
  functioneel; bevestig dat de bestaande tests nog groen zijn met `python3
  modules/linny-mcp-authz/linny_mcp_authz_test.py`).

## 5. Documentatie

- [x] 5.1 `docs/linny-mcp.md`: de route-matrix bijwerken (publiek kan read+write mits switch aan),
  de `publicWrite`-switch en de `linny-mcp-write`-policy beschrijven, en de token-tabel
  (`claude-web` = `write:*`) corrigeren. Verifieer dat de tabellen kloppen met de nieuwe config.
- [x] 5.2 CLAUDE.md: korte notitie/sessie-entry met de switch, de policy en de secret-paden, plus
  de stdin-waarschuwing bij `ragenx`.

## 6. Deploy en verificatie

- [ ] 6.1 `sudo nixos-rebuild switch --flake .#malandro` met `publicWrite = false`. Verifieer:
  publieke route nog read-only (`create_doc` via Authelia-token geweigerd), en de tunnel-token doet
  nu `write:*` (bestaande notitie wijzigbaar via Claude Code).
- [ ] 6.2 Testvenster: `publicWrite = true` → `switch` → via Claude Mobile/Online een schrijfaanroep
  doen en bevestigen dat die slaagt → daarna `publicWrite = false` → `switch` → bevestigen dat
  schrijven weer geweigerd wordt. Observeer `journalctl -u linny-mcp` en `nginx-access.log`.
