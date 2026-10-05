---
# nixos-38kf
title: 'Gelekte secrets in repo: geroteerd, opgeruimd, historie gepurged'
status: completed
type: bug
priority: critical
tags:
    - security
    - authelia
    - history-purge
created_at: 2026-10-05T15:57:39Z
updated_at: 2026-10-05T19:46:44Z
---

Aanleiding: `secrets/` bevatte plaintext-bestanden (Authelia `.txt`) in de toen publieke repo.
Een scan van de hele historie (gitleaks + eigen patronen) vond meer. Afgehandeld op 2026-10-05.

## Bevindingen en afhandeling
- **Authelia `.txt`**: oude waarden, live sinds `b62f0b1` (april) al anders (op hash geverifieerd). Verwijderd.
- **HA long-lived token** (Prometheus-scrape) plaintext in de code → nieuw token, agenix
  (`homeassistant-prometheus-token.age`), oud token ingetrokken. Prometheus in `keys`-groep.
- **SES `AKIAVXIW…`** (key-ID + SMTP-wachtwoord gelekt, ander account) → verwijderd in IAM.
  **SES `AKIAXIOE…`**: alleen ID gelekt, in gebruik door postfix → bewust niet geroteerd.
- **msmtp / `hosts/lobos/mail.nix`**: ongebruikt → verwijderd (wachtwoord nooit plaintext in git).
- **WireGuard-privékey** (uitgecommentarieerd, malandro): geen actieve peer → verwijderd.
- **Bitwarden `data.json`** (2024, als `bwconfig.age`, onversleuteld) → master password gewijzigd + key-rotatie.
- **Klantenlijst TechNative** (`managed_service_accounts.nix`) → verwijderd.
- **Authelia argon2id-hashes** → `authelia-password-hashes.age`; users-db wordt in de preStart
  samengesteld (0600). **Signal-nummers** → `signal-numbers.age`.
- `modules/dns`: TSIG-key via `knot.keyFiles` i.p.v. `builtins.readFile`. Backup-bestanden en `credentials.2` weg.
- `workload`-recipient: als afgehandeld beschouwd.

## Preventie
- `.gitignore`: in `secrets/` alleen `*.age` en `secrets.nix`.
- `.githooks/pre-commit`: gitleaks op gestagede wijzigingen (via globale hooksPath-dispatcher).

## Historie
- `git filter-repo`: 19 paden weg, 7 waarden en de patronen argon2id-`passwordHash` en
  WireGuard `privateKey`/`presharedKey` → `***REMOVED***`. gitleaks: 51 → 8 (alleen vals-positief).
- GitHub-repo verwijderd en opnieuw aangemaakt (PR-refs hielden oude commits bereikbaar);
  alleen `main` + tag gepusht. Oude commits geven "No commit found". Alle clones vervangen.

## Deploy
- PR #104 en #105 gemerged. malandro gen 577: Authelia start schoon, HA-target up, secrets aanwezig.

## Restpunten (niet in scope)
- `modules/wg.nix`: bcrypt `PASSWORD_HASH` van wg-easy staat nog in de code (eventueel naar agenix).
- `home/awsconf.nix` bevat klant-account-ID's: bewust gelaten.
- Repo weer publiek maken: keuze van de gebruiker.
