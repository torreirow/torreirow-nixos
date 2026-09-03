# Tasks — add-vaultwarden-restore-test

## 1. Script (bron in repo)
- [x] 1.1 `home/module/vaultwarden-restore-test/vaultwarden-restoretest.sh` aanmaken (`#!/usr/bin/env bash`, `set -euo pipefail`)
- [x] 1.2 Arg-parsing: default / `--rbw` / `--snapshot <id>` / `--keep` / `--destroy` / `--help`
- [x] 1.3 Vaste resources: `WORK=/tmp/vw-restoretest`, container `vaultwarden-restoretest`, poort `127.0.0.1:8099`

## 2. Basis-test
- [x] 2.1 `sudo rustic restore <snap>:/var/lib/vaultwarden` → `$WORK/data`
- [x] 2.2 `sudo rustic restore <snap>:/var/backup/db/vaultwarden.sqlite3` → reassemble naar `$WORK/data/db.sqlite3`
- [x] 2.3 wegwerp-container (bridge, `ROCKET_ADDRESS=0.0.0.0`, `-p 127.0.0.1:8099:8080`)
- [x] 2.4 healthcheck `curl /alive` == 200 + `/api/config`
- [x] 2.5 sqlite-tellingen (users, ciphers) uit `$WORK/data/db.sqlite3`

## 3. rbw-crypto-test (`--rbw`)
- [x] 3.1 XDG_*-override naar `$WORK/rbwhome/{config,cache,data,state,run}` (0700 op run-dir)
- [x] 3.2 email read-only uit echte rbw-config (`jq .email ~/.config/rbw/config.json`)
- [x] 3.3 `rbw config set base_url http://127.0.0.1:8099` + email + `pinentry-tty` (in geïsoleerde config)
- [x] 3.4 `rbw login` (master-pw via pinentry + **TOTP** interactief) → `rbw sync`
- [x] 3.5 `rbw list | wc -l` → aantal ontsleutelde items rapporteren; niet-nul = succes
- [x] 3.6 (optioneel) `rbw get <bekend item>` als concrete decrypt-proef

## 4. Cleanup & robuustheid
- [x] 4.1 `--destroy`: `rbw stop-agent` (geïsoleerd) + `docker rm -f` + `sudo rm -rf $WORK` (idempotent)
- [x] 4.2 `trap ... EXIT` → teardown bij fout halverwege, tenzij `--keep`
- [x] 4.3 Vooraf oude container verwijderen + poort 8099 vrij-check
- [x] 4.4 rustic-binary robuust resolven

## 5. Home-manager deploy
- [x] 5.1 `home/module/vaultwarden-restore-test/default.nix` met `home.file."bin/vaultwarden-restoretest.sh"` (`executable = true`, `readFile`)
- [x] 5.2 Import in `home/linux-server.nix`
- [x] 5.3 `home-manager switch` → `~/bin/vaultwarden-restoretest.sh` staat er en is uitvoerbaar

## 6. Verificatie
- [x] 6.1 Basis-test end-to-end (container start, /alive 200, counts kloppen)
- [ ] 6.2 `--rbw` end-to-end (login + TOTP → list toont items) — HANDMATIG door user (interactief master-pw + TOTP; kan niet autonoom)
- [x] 6.3 `--destroy` ruimt container + `$WORK` + rbw-agent op; live Vaultwarden + echte rbw-config aantoonbaar ongemoeid
- [x] 6.4 Korte gebruiksuitleg in CLAUDE.md (of de docs/) + verwijzing vanuit de rustic-sessie
