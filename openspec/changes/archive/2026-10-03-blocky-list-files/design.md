## Context

`modules/blocky.nix` (één bestand, ~210 regels) bevat service, container, nginx, secrets, de
runtime-render-pipeline én de blocking-policy. Eigen domeinlijsten staan als inline YAML-blokken.
blocky draait als `DynamicUser` met `ProtectSystem=strict`; de query-log gaat naar MariaDB en de
StateDirectory (`/var/lib/private/blocky`) is leeg — blocky is in deze opzet effectief stateless.

Geverifieerd tegen blocky 0.35 (deels pas bij runtime, niet via `validate`):
- Een denylist/allowlist-groep accepteert **meerdere bronnen** en voegt ze samen (union).
- **Een bron is een BESTAND**, geen directory of glob. `validate` keurt een dir/glob goed, maar bij
  runtime faalt blocky: dir → "is a directory", glob → "cannot open file '*'". Daarom: één
  overlay-**bestand** per groep (niet een drop-in directory). Een los bestand werkt wél.
- `POST /api/lists/refresh` herlaadt alle bronnen zonder restart (loopback, base `/api`).
- `loading.refreshPeriod` (default 4u) herlaadt sowieso periodiek.
- blocky leest `/data/external` (externe mount, `/dev/sdb1`) prima onder `ProtectSystem=strict` —
  geen `ReadOnlyPaths`/bind nodig.

## Goals / Non-Goals

**Goals:**
- Domeinlijsten als platte tekst in git (reviewbaar, geen YAML-escaping).
- Een mutabele overlay per groep voor snelle wijzigingen zonder rebuild.
- `blocky.nix` leesbaar opsplitsen (service vs. policy vs. lijsten).
- Overlays in de backup.

**Non-Goals:**
- De LAN-cutover (blocky blijft `127.0.0.1:53` tot apart besloten).
- De concrete `block-boaz`-inhoud (domeinen/IP/tijden) — dit levert alleen het patroon; invullen
  gebeurt daarna triviaal.
- StateDirectory verplaatsen (onnodig: stateless; en `StateDirectory=` kan geen vrij pad zijn).

## Decisions

### Baseline (git) + overlay (mutabel) in dezelfde groep
**Beslissing**: elke eigen groep krijgt twee bronnen:
`denylists.<groep> = [ ./lists/<groep>.txt  "/data/external/blocky/denylists.d/<groep>.txt" ]`, en
een allowlist-overlay `allowlists.<groep> = [ "/data/external/blocky/allowlists.d/<groep>.txt" ]`.
(Overlay = één bestand per groep; blocky ondersteunt geen directory/glob als bron.)
**Rationale**: blocky voegt bronnen samen. De baseline is declaratief en kan nooit kwijt; de overlay
is voor snel sleutelen. Een allowlist-overlay maakt live de-blokkeren mogelijk.
**Alternatief**: alleen baseline (geen snelle route) of alleen mutabel (niet in git, drift) — beide
afgewezen; de combinatie geeft het beste van beide.

### Overlay-locatie: /data/external/blocky, als bestand per groep
**Beslissing**: overlay-bestanden op `/data/external/blocky/{denylists.d,allowlists.d}/<groep>.txt`,
via `systemd.tmpfiles` leeg aangemaakt (`f ... 0644 root root`), bewerken met `sudo`. StateDirectory
blijft default.
**Rationale**: blocky hoeft de overlays alleen te **lezen**; onder `ProtectSystem=strict` is lezen
toegestaan (geverifieerd — blocky bereikt `/data/external`), dus geen `DynamicUser`-opgave, geen
`BindPaths`, geen StateDirectory-verhuizing. `0644` → blocky (DynamicUser) leest via o+r.
`/data/external` is tevens de backup-schijf-conventie van deze host.

### Naamgeving denylists.d / allowlists.d
**Beslissing**: `denylists.d/` en `allowlists.d/` (zelf-documenterend, sluit aan op blocky's eigen
`denylists`/`allowlists`). Niet één umbrella `overlay/`.

### Nix-structuur (directory-module)
**Beslissing**: `modules/blocky/default.nix` (infra: service, container, nginx, secrets, render,
tmpfiles, helper) + `modules/blocky/blocking.nix` (de `blocking`-settings) + `modules/blocky/lists/`.
`configuration.nix` importeert de dir (`../../modules/blocky`). `blocking.nix` levert het
`blocking`-attrset dat `default.nix` in `blockyBaseSettings` opneemt.
**Rationale**: service-infra en beleid zijn verschillende dingen; lijsten zijn weer data.

### Refresh-helper
**Beslissing**: klein script `blocky-refresh` → `curl -fsS -X POST http://127.0.0.1:4000/api/lists/refresh`.
**Rationale**: overlay bewerken + `sudo? nee, loopback` → `blocky-refresh` = direct actief. Zonder
helper duurt het tot `refreshPeriod`.

## Risks / Open Issues (opgelost tijdens implementatie)

- **Sandbox-zichtbaarheid van `/data/external`**: geen probleem — blocky leest de overlay-bestanden
  onder `ProtectSystem=strict` (geverifieerd met een deny-/allow-overlaytest).
- **Bron = bestand, geen directory/glob**: aanvankelijk gepland als drop-in dir, maar blocky faalt
  bij runtime op een dir ("is a directory") en glob ("cannot open '*'"). Opgelost: één overlay-
  **bestand** per groep. `validate` ving dit niet (leest bronnen niet).
- **Refresh-foutstilte**: `blocky-refresh` gebruikt `curl -fsS` (faalt zichtbaar met HTTP-status),
  geen `|| true`.
