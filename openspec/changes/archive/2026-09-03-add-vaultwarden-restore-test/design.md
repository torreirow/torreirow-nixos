# Design — add-vaultwarden-restore-test

## Data-flow (volledige `--rbw` run)

```
S3 snapshot (rustic)
  │ (sudo) rustic restore latest:/var/lib/vaultwarden        → $WORK/data
  │ (sudo) rustic restore latest:/var/backup/db/vaultwarden.sqlite3
  │        reassemble:  cp vaultwarden.sqlite3 → $WORK/data/db.sqlite3
  ▼
docker run --name vaultwarden-restoretest (bridge, 127.0.0.1:8099)
  │ curl /alive → 200
  │ sqlite3 count users / ciphers
  ▼
rbw (XDG-geïsoleerd, eigen agent)
  base_url=http://127.0.0.1:8099, email uit echte rbw-config (read-only)
  rbw login  → master-pw (pinentry-tty) + TOTP-code
  rbw sync → rbw list | wc -l   → N ontsleutelde items
  ▼
"users=13, ciphers=1367, rbw ontsleutelde N items ✓"
```

## Kernbesluiten

### Source of truth = repo, deploy via home-manager
Het script leeft in de repo (`home/module/vaultwarden-restore-test/vaultwarden-restoretest.sh`) en wordt via `home.file."bin/vaultwarden-restoretest.sh" = { executable = true; text = builtins.readFile ...; }` naar `~/bin/` gedeployed — exact het patroon van `export-ssh-keys.sh`. Geïmporteerd via `home/linux-server.nix` (geldt voor wtoorren op malandro). Geen los, onbeheerd bestand in `~/bin`.

### rbw-isolatie via XDG_*-override (niet de echte rbw aanraken)
De echte rbw wijst naar `https://vw.toorren.net` (`~/.config/rbw/config.json`). De test zet `XDG_CONFIG_HOME/CACHE/DATA/STATE/RUNTIME` naar submappen van `$WORK/rbwhome`, zodat de geïsoleerde rbw + `rbw-agent` daar volledig leven. Cleanup = `rm -rf $WORK` (na `rbw stop-agent`). Deterministischer dan `RBW_PROFILE` (waarvan het configpad minder expliciet is). Het test-e-mailadres wordt **read-only** uit de echte rbw-config gelezen (`jq .email`), zodat het je eigen account test zonder die config te wijzigen.

### 2FA blijft staan → TOTP interactief
De gerestorede DB bevat de 2FA-config. `rbw login` vraagt dus om een TOTP-code na de master-password. Dat is bewust: het bewijst dat óók de 2FA-config correct is teruggezet. Consequentie: `--rbw` is inherent interactief (master-pw via pinentry-tty + TOTP), dus niet cron-baar. De basis-test (zonder `--rbw`) is wél volledig automatisch.

### Non-destructief, met vaste resources voor `--destroy`
```
WORK=/tmp/vw-restoretest
  ├── data/                     (root-owned; container-volume, restored files)
  └── rbwhome/{config,cache,data,state,run}   (user-owned; geïsoleerde rbw)
container: vaultwarden-restoretest   (bridge, 127.0.0.1:8099)
```
`--destroy`:
```
XDG_*=$WORK/rbwhome/... rbw stop-agent   2>/dev/null || true
docker rm -f vaultwarden-restoretest     2>/dev/null || true
sudo rm -rf "$WORK"
```
Idempotent (`|| true`, `rm -f`) — veilig ook als er niets draait.

### Sudo-mix
Script draait als `wtoorren` (nodig voor pinentry-tty + rbw-agent + het eigen account), en `sudo`t alleen de root-delen: `rustic restore` (creds in `/run/agenix`, profiel in `/etc/rustic`) en `docker`. De restored data is root-owned; rbw raakt die niet aan (praat enkel HTTP met de container).

### Bridge, niet host-network
De live Vaultwarden draait met `--network=host` op 8080; de test moet dus een los poort pakken via bridge: `-p 127.0.0.1:8099:8080` met `ROCKET_ADDRESS=0.0.0.0` in de container.

## Robuustheid
- `set -euo pipefail` + `trap` op EXIT die naar de teardown valt bij een fout halverwege (tenzij `--keep`), zodat er geen half-opgestarte container blijft hangen.
- rustic-binary robuust resolven (`nix build --no-link --print-out-paths nixpkgs#rustic` of een gepind pad).
- Vooraf `docker rm -f` van een oude test-container + check dat 8099 vrij is.
- Shebang `#!/usr/bin/env bash` (repo-conventie).

## Bewezen aannames (deze sessie)
- rbw 1.15 praat over plain `http` (localhost) — geen https-dwang.
- Vaultwarden-container start uit de gerestorede data (`/alive` → 200, `Rocket has launched`).
- Restore-round-trip van de dump → `integrity_check: ok`, 13 users / 1367 ciphers.
- `twofactor`-tabel bevat rijen → 2FA actief (vandaar de TOTP-keuze).
