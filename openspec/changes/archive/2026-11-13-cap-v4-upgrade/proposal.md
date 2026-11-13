# Proposal

## Why

Cap staat sinds 2026-10-12 vastgepind op de digest van 3.1.15, omdat elke 4.0-build met
`Illegal instruction` crashte op malandro's Celeron J3455. De oorzaak bleek niet Bun maar de
meegeleverde DuckDB 2.0 (AVX2+FMA); upstream loste dat op in 4.0.9 (crash weg) en 4.0.10
(DuckDB 1.4.5, analytics werkt op niet-AVX2-CPU's). `4.0.12` start op malandro (getest: HTTP 200,
52 MB RSS), dus de pin is niet langer nodig en 3.1.15 krijgt geen fixes meer.

Cap is de captcha achter twee publieke formulieren (contactmailer en File Drop). Op 3.x is dat
alleen proof-of-work; 4.x voegt per-request analytics en bot-/AI-agentdetectie toe, wat juist voor
die twee formulieren relevant is.

## What Changes

- Image van `tiago2/cap@sha256:7327a14…` (3.1.15) naar de digest van **4.0.12**.
- **BREAKING**: v4 hasht alle opgeslagen secrets opnieuw. Elke site-key moet zijn secret opnieuw
  krijgen; tot dat gebeurt geeft `/siteverify` 403 en falen beide formulieren. De site-key-id's
  zelf (`eaa5abea30` voor de mailer, `92c7e198d7` voor filedrop) en alle instellingen blijven geldig.
- **BREAKING**: dashboard-sessies van v3 vervallen; opnieuw inloggen met `ADMIN_KEY`.
- Nieuw persistent volume voor de event store op `/usr/src/app/data` (DuckDB). Zonder volume is de
  analytics-database weg bij elke container-herstart.
- Valkey-snapshot vóór de upgrade als terugweg (site keys, settings, sessies leven daar).
- Agenix-secrets bijwerken: `cap-mailer-secret.age` en `CAP_SECRET` in `filedrop-env.age`, daarna
  mailer en filedrop opnieuw deployen.
- Comment in `modules/cap.nix` corrigeren (DuckDB/AVX2, niet Bun) en `docs/filedrop.md` bijwerken
  met de nieuwe secret-rotatie.
- Niet van toepassing: ClickHouse (analytics blijven in DuckDB), API-keys (we gebruiken er geen),
  en de vervallen env-vars (`DEMO_MODE`, `RSW_BITS`, `SHOW_ERRORS`, …) — die zetten we niet.

## Capabilities

### New Capabilities

- `cap-captcha-hosting`: lokaal gehoste Cap-instance op malandro als captcha-voorziening voor de
  publieke formulieren — bereikbaarheid, persistentie van keys/events, secret-rotatie per
  consumer, draaien op een CPU zonder AVX2, en een upgrade die `/siteverify` niet stil breekt.

### Modified Capabilities

Geen. De contracten van `contact-mailer` (siteverify met `{"secret","response"}`) en `filedrop`
(captcha-token verplicht) veranderen niet; alleen de waarde van het secret verandert.

## Impact

- `modules/cap.nix` — image-digest, event-volume, commentaar.
- `secrets/cap-mailer-secret.age`, `secrets/filedrop-env.age` — nieuwe secrets (agenix rekey niet
  nodig, alleen inhoud).
- `modules/mailer.nix`, `modules/filedrop.nix`, `hosts/malandro/configuration.nix` — geen
  codewijziging; wel herdeploy na de secret-rotatie.
- `docs/filedrop.md`, `CHANGELOG.md`.
- Runtime op malandro: `cap` + `cap-valkey` containers, `/data/external/cap/{valkey,events}`,
  nginx-vhost `cap.toorren.net` (ongewijzigd).
- Tijdelijke uitval van beide captcha's tijdens de rotatie (seconden tot minuten, alleen als er
  precies dan iemand een formulier verstuurt).
