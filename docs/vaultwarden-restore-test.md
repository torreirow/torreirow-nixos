# Vaultwarden restore-test

Herhaalbare, non-destructieve restore-test van de rustic S3-backup van Vaultwarden.
Bron: `home/module/vaultwarden-restore-test/vaultwarden-restoretest.sh` (via home-manager
gedeployed naar `~/bin/vaultwarden-restoretest.sh`). Zie OpenSpec change
`add-vaultwarden-restore-test` en de rustic-backup sessie in `CLAUDE.md`.

## Gebruik

```bash
vaultwarden-restoretest.sh                # basis-test (volledig automatisch)
vaultwarden-restoretest.sh --rbw          # + rbw crypto-test (interactief: master-pw + TOTP)
vaultwarden-restoretest.sh --snapshot ID  # specifieke backup (default: latest)
vaultwarden-restoretest.sh --keep         # laat container + data staan om te snuffelen
vaultwarden-restoretest.sh --destroy      # ruimt alles op (vangnet)
```

Een gewone run ruimt zichzelf op via een EXIT-trap (bij succes én fout). `--destroy` is
alleen nodig na `--keep` of na een harde afbreking (`kill -9`, stroomuitval).

## Proces-flow (incl. locaties)

Legenda: 🔴 = root/sudo · 🔵 = user (wtoorren)

```
                        ~/bin/vaultwarden-restoretest.sh   (HM-symlink -> nix-store)
                                     |
        +----------------------------+----------------------------+
        |  args: (default) | --rbw | --snapshot ID | --keep | --destroy
        +----------------------------+----------------------------+
                                     |
   +---------------------------------v---------------------------------+
   | 0. rustic resolven                                                |
   |    RUSTIC = nixpkgs#rustic  (nix-store, gecached)                 |
   +---------------------------------+---------------------------------+
                                     |
   [red]+[blue] 1. PREPARE           v
        sudo rm -rf /tmp/vw-restoretest        <- oude run wegvegen (root)
        mkdir -p   /tmp/vw-restoretest/data    <- nieuw, USER-owned
        check poort 8099 vrij
                                     |
   [red] 2. RESTORE  (rustic, met creds + profiel)
        +-----------------------------------------------------------+
        | bron  : s3://wto-s3-bucket/rustic-backup/malandro         |
        | creds : /run/agenix/rustic-s3-env  (AWS key/secret)       |
        | pw    : /run/agenix/rustic-repo-password                  |
        | profiel: /etc/rustic/malandro.toml                        |
        +-----------------------------------------------------------+
        #1  latest:/var/lib/vaultwarden          --> /tmp/vw-restoretest/data/
              (attachments, rsa_key.pem, config.json, sends, ...)
        #2  latest:/var/backup/db/vaultwarden.sqlite3 --> /tmp/vw-restoretest/data/
              (WARN "additional entries" = onschuldig; map was al gevuld)
                                     |
   [red] 3. REASSEMBLE               v
        mv  .../data/vaultwarden.sqlite3  ->  .../data/db.sqlite3   (dump wordt de DB)
        sqlite3 PRAGMA quick_check -> ok
                                     |
   [red] 4. WEGWERP-CONTAINER        v
        docker run --name vaultwarden-restoretest
          bridge  -p 127.0.0.1:8099:8080
          -v /tmp/vw-restoretest/data:/data
          vaultwarden/server:latest
                                     |
   [blue] 5. HEALTHCHECK             v
        curl http://127.0.0.1:8099/alive   -> HTTP 200
                                     |
   [red] 6. COUNTS                   v
        sqlite3 .../db.sqlite3  -> users, ciphers
                                     |
        +----------------------------+--- alleen met --rbw ---+
                                     |
   [blue] 7. rbw CRYPTO-TEST (geisoleerd)
        XDG_* -> /tmp/vw-restoretest/rbwhome/{config,cache,data,state,run}
        email  <- ~/.config/rbw/config.json   (READ-ONLY, ongewijzigd)
        rbw config set base_url http://127.0.0.1:8099   (in de geisoleerde config)
        rbw login   -> master-pw (pinentry) + TOTP-code
        rbw sync -> rbw list   -> N ontsleutelde items
                                     |
   === EXIT-trap (altijd, tenzij --keep) ============================
   [blue][red] 8. TEARDOWN
        rbw stop-agent            (geisoleerde agent onder rbwhome)
        docker rm -f vaultwarden-restoretest
        sudo rm -rf /tmp/vw-restoretest
```

## Locatie-overzicht

| Rol | Locatie | Aangeraakt? |
|-----|---------|-------------|
| Script (bron) | `home/module/vaultwarden-restore-test/` in repo | — |
| Script (deployed) | `~/bin/vaultwarden-restoretest.sh` -> nix-store | read |
| Backup-bron | `s3://wto-s3-bucket/rustic-backup/malandro` | **read-only** |
| rustic-creds/profiel | `/run/agenix/rustic-*`, `/etc/rustic/malandro.toml` | read |
| Werkmap (vluchtig) | `/tmp/vw-restoretest/data` + `/rbwhome` | **read/write -> gewist** |
| Wegwerp-container | `vaultwarden-restoretest` @ `127.0.0.1:8099` | **create -> verwijderd** |
| **Live Vaultwarden** | `vaultwarden` @ `:8080`, `/var/lib/vaultwarden` | **NIET aangeraakt** |
| **Echte rbw** | `~/.config/rbw` (-> `vw.toorren.net`) | **NIET aangeraakt** |

## Isolatie / veiligheid

- De enige `/var/lib/vaultwarden`-verwijzing is de **bron** van een rustic-restore (pad ín de
  S3-snapshot), niet de live schijf. Restore leest uit S3 en schrijft naar `/tmp`.
- De wegwerp-container draait op een **los poort (8099)** via bridge, met een eigen naam en een
  eigen data-volume in `/tmp`. De live container (`:8080`, host-network) blijft ononderbroken.
- rbw is via **XDG-override** volledig geïsoleerd: eigen config + eigen agent, praat alleen met
  `127.0.0.1:8099`. De echte `~/.config/rbw` (naar `vw.toorren.net`) wordt niet gewijzigd.
- `rbw login` registreert een device in de **wegwerp-kopie** van de DB, niet in de live DB. De
  test-container heeft geen SMTP -> geen "nieuw device"-mail.
- Alles onder `/tmp/vw-restoretest` en de container is vluchtig (trap of `--destroy`).
