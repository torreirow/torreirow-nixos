# Design

## Context

Zie `proposal.md` voor de motivatie. Huidige stand (gecontroleerd op malandro, 2026-11-13):

- `modules/cap.nix`: `cap` (image digest 3.1.15) + `cap-valkey` (valkey 9-alpine) op eigen netwerk
  `cap-net`, cap alleen op `127.0.0.1:3009`, `REDIS_URL` naar de valkey-container, `ADMIN_KEY` via
  `--env-file` uit agenix. Valkey-data in `/data/external/cap/valkey` (uid 999).
- Consumers: mailer met site-key `eaa5abea30` (secret `secrets/cap-mailer-secret.age`), filedrop met
  site-key `92c7e198d7` (`CAP_SECRET` in `secrets/filedrop-env.age`). Beide valideren via
  `POST https://cap.toorren.net/<key>/siteverify`.
- Hardware: Celeron J3455 (geen AVX2), 7,6 GB RAM met ~2,4 GB swap in gebruik.
- Getest op 2026-11-13: `tiago2/cap:4.0.12` start hier (HTTP 200, 52 MB RSS); Bun 1.4.4 is niet het
  probleem, de oude crash kwam van DuckDB 2.0 (opgelost in 4.0.9/4.0.10).

## Goals / Non-Goals

**Goals:**

- Cap op 4.0.12 met dezelfde publieke URL en dezelfde site-keys, zonder dat de twee formulieren
  merken dat de server is vervangen (afgezien van de secret-rotatie).
- Events en keys persistent, zodat een herstart of image-upgrade geen data of bootstrap kost.
- Eén gedocumenteerd terugrolpad.

**Non-Goals:**

- ClickHouse voor analytics (extra dienst, te zwaar voor deze NUC).
- Proxy sign-in via Authelia voor het Cap-dashboard (blijft `ADMIN_KEY`).
- Nieuwe Cap-functionaliteit (rules, webhooks, API-keys) inzetten; die blijft ongebruikt.
- Widgetversies in de sites ophogen, tenzij de test daarom vraagt.

## Decisions

**Image: `tiago2/cap@sha256:e9cd4884f35ca6bcedb6a27fa92be55813bfe64fe2cae93a084ec8d20e1aebd5` (4.0.12).**
Digest boven tag `4`/`latest`, net als nu: een rebuild mag nooit stil een andere versie opleveren.
4.0.12 en niet 4.0.9/4.0.10/4.0.11: 4.0.9 zet analytics uit op niet-AVX2, 4.0.10/4.0.11 hadden
respectievelijk de DuckDB-conversie en een analytics-500; 4.0.12 is de nieuwste met de
WebAssembly-fallback erbij.

**`REDIS_URL` wordt `VALKEY_URL`.** v4 heeft de variabele hernoemd (default
`redis://localhost:6379`). Zonder deze wijziging start Cap zonder foutmelding maar zonder Valkey —
site-keys en challenges verdwijnen dan in het niets. Dit is de belangrijkste niet-obvious stap.

**Event store als bind mount, geen ClickHouse.** `DATA_DIR` is al `/usr/src/app/data` in de image;
we mounten `${dataDir}/events` daarheen, eigendom `1000:1000` (de container draait als `bun`,
uid 1000). `DUCKDB_MEMORY_LIMIT=128MB` (default 256MB) houdt de voetafdruk klein op een host die
al swapt. ClickHouse afgewezen: tweede stateful dienst, honderden MB's, en de informatiewaarde
voor ~40 solves/dag weegt daar niet tegenop.

**Valkey blijft zoals het is.** Zelfde container, zelfde volume. Voor de upgrade één snapshot
(`valkey-cli SAVE` + kopie van `dump.rdb` naar `/data/external/cap/backup-<datum>.rdb`); dat is
meteen het terugrolpad.

**Volgorde van de secret-rotatie.** Eerst image + volume uitrollen, dan in het dashboard beide
secrets resetten, dan agenix bijwerken (`agenix -e`), dan mailer en filedrop herdeployen, dan de
acceptatiecheck. Andersom kan niet: v3 kent geen reset, en een v4-secret werkt niet op v3.

**`X-Forwarded-For $remote_addr` in de nginx-vhost.** v4 rate-limit per IP op de socket-address en
negeert forwarding-headers tot je in het dashboard onder *Instance settings → Visitor location* je
proxy kiest. Met de huidige `$proxy_add_x_forwarded_for` (die een client zelf kan aanvullen) plus
de dashboard-instelling is het gedrag bovendien spoofbaar; de documentatie schrijft `$remote_addr`
voor. Zonder deze twee stappen delen alle bezoekers één bucket van 30 challenges/5 s.

**Commentaar in `modules/cap.nix` rechtzetten.** De "Bun vereist AVX"-notitie is onjuist; het was
DuckDB. Zonder correctie wordt de volgende upgrade weer op de verkeerde grond gepind.

## Risks / Trade-offs

- **Formulieren geven 403 tussen secret-reset en herdeploy** → in één sessie doen, direct na de
  reset de consumers deployen, en met `curl` op `/siteverify` controleren vóór je het afgerond
  noemt. Verkeer is laag (~40 solves/dag), dus het venster is in de praktijk seconden.
- **Terugrollen na een reset vraagt een tweede reset** → upstream: een op v4 geroteerd secret kan
  v3 niet lezen. Het terugrolplan noemt daarom expliciet: snapshot terug, digest terug, en beide
  secrets op v3 opnieuw zetten + agenix bijwerken.
- **DuckDB op niet-AVX2 kan alsnog beperkt zijn** → 4.0.10 claimt werkende analytics met DuckDB
  1.4.5; de captcha werkt hoe dan ook. Acceptatie: `/health` 200 en een echte solve, niet of het
  analytics-scherm gevuld is.
- **Widget in de sites is oud (jsDelivr `@cap.js/widget@0.1.58`)** → het siteverify-contract is
  ongewijzigd, maar test beide formulieren in een echte browser; breekt het, dan is de
  widgetversie in `pkgs/filedrop/index.html` en de mailer-template de eerste knop.
- **Geheugen** → 52 MB gemeten plus 128 MB DuckDB-limiet; malandro swapt al, dus na de upgrade
  `docker stats` en `free -h` controleren.

## Migration Plan

1. Snapshot: `docker exec cap-valkey valkey-cli SAVE`, daarna
   `cp /data/external/cap/valkey/dump.rdb /data/external/cap/backup-<datum>.rdb`.
2. Module aanpassen (image, `VALKEY_URL`, events-volume + tmpfiles, `DUCKDB_MEMORY_LIMIT`,
   nginx-header), `nixos-rebuild switch`.
3. `docker logs cap` controleren: geen SIGILL, `Cap running`, `/health` 200.
4. Inloggen op `https://cap.toorren.net` met `ADMIN_KEY`; beide keys hebben een "Reset secret"-tag.
5. Per key het secret resetten en vastleggen in agenix:
   `agenix -e secrets/cap-mailer-secret.age` en `CAP_SECRET` in `agenix -e secrets/filedrop-env.age`.
6. Mailer + filedrop herdeployen (`nixos-rebuild switch`).
7. Acceptatie: `/health` 200, `siteverify` geeft `success: true` voor beide keys, één echte
   mail via een contactformulier en één echte upload via File Drop.
8. Terugrolpad: digest terug naar 3.1.15, snapshot terugzetten, `switch`, en de secrets op v3
   opnieuw zetten zoals hierboven beschreven.
