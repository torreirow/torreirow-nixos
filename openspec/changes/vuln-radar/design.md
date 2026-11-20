# Design

## Context

Zie `proposal.md` voor de motivatie. De bestaande `status-dashboard`-service is het patroon:
Python-stdlib, alleen op `127.0.0.1`, nginx + Authelia ervoor. FreshRSS draait op malandro met
SQLite en wordt elke 5 minuten ververst; de dashboardlaag mag daar read-only uit lezen.

De testassets laten de drie bronnen zien die het ontwerp moet ondersteunen:

- upstream: nginx 1.30.7 (0 recente CVE's) en PHP 8.3.36 (13 CVE's, fixed 8.3.37);
- Debian trixie met Nix: Apache 2.4.67 (±36 CVE's), PHP 8.3.37 (0), kernel 6.12.74-2
  (trixie fixed op 6.12.117-1).

## Goals / Non-Goals

**Goals:**

- Per systeem en package alleen CVE's tonen waarvan de geïnstalleerde versie aantoonbaar onder
  de fixed version ligt.
- Eén asset kan packages uit `dpkg`, `nix` en `upstream` mengen.
- Eigen NixOS-hosts automatisch inventariseren; externe hosts via JSON.
- Zichtbaar maken wanneer data ontbreekt of verouderd is.

**Non-Goals:**

- Geen automatische ontdekking van hosts of packages buiten de aangeleverde inventaris.
- Geen GUI om versies te bewerken; de configuratie is Nix + JSON.
- Geen Docker-image- of container-image-scan in v1.
- Geen vervanging van FreshRSS; filters en feeds blijven zoals ze zijn.
- Geen garantie dat elke CVE ter wereld gevonden wordt; onbekend blijft onbekend.

## Decisions

### 1. Inventaris: Nix-optie plus één JSON-bestand

De NixOS-module krijgt `services.vuln-radar.assets` en `extraAssetsFile`. De module schrijft
`/etc/vuln-radar/assets.json`; de service leest alleen dat bestand. Eigen hosts komen uit de
flake, externe hosts uit JSON.

Per host:

```json
{
  "os": "debian",
  "release": "trixie",
  "esm": false,
  "dpkg": { "openssl": "3.5.7-1~deb13u3" },
  "nix": { "apache2": "2.4.67", "php": "8.3.37" },
  "upstream": {}
}
```

Gescheiden maps in plaats van één map met een `source`-veld: de bron bepaalt de
vergelijkingsmethode en de databron, en zo kan een package niet per ongeluk met de verkeerde
tracker worden vergeleken. Een package dat in meerdere maps staat is een configuratiefout.

**Alternatief overwogen:** automatisch `dpkg-query`/`nix-store` op elke host draaien. Afgewezen
voor v1: vereist toegang en een agent per host; de aangeleverde JSON is reproduceerbaar en
reviewbaar.

### 2. Matching is inventaris-gedreven, FreshRSS is context

De matcher loopt over assets en packages, niet over feed-items. FreshRSS levert alleen titel,
link, bron en publicatiedatum bij een gevonden CVE. Daarmee worden CVE's die niet in de feeds
staan alsnog gevonden en blijven de feeds bruikbaar voor context.

**Alternatief overwogen:** alleen CVE's uit FreshRSS evalueren. Afgewezen: de feedtekst is
afgekapt (PHP-entry: 638 bytes) en mist daardoor CVE's.

### 3. Bron per ecosystem

| Ecosystem | Bron | Vergelijking |
|---|---|---|
| Debian | Security Tracker JSON of per-CVE trackerpagina | `python-debian` (dpkg-volgorde) |
| Ubuntu | `ubuntu.com/security/cves.json?package=<pkg>` | `python-debian`, ESM-pocket respecteren |
| Nix | `vulnix --json` en NVD als fallback | Nix/vulnix, anders semver |
| Upstream | NVD `affected`/CPE plus vendor-changelog | semver/`packaging` |
| KEV | CISA KEV JSON | alleen exploitatie-indicator |

De Debian-tracker-JSON is ±91 MB; die wordt dagelijks opgehaald en gefilterd op de packages in
de inventaris. Voor Ubuntu is de per-package-API klein (nginx: ±43 KB) en actueel.

### 4. Alleen `installed < fixed`

De matcher vergelijkt per release de geïnstalleerde versie met de fixed version. Ontbreekt een
fixed version of is de bron niet beschikbaar, dan wordt het resultaat `unknown` en niet
`applicable`. Unknown wordt apart geteld en nooit als schone pagina gepresenteerd.

### 5. Service en UI

- Python 3 stdlib + `python-debian`; geen framework.
- Luistert op `127.0.0.1:9101`; nginx-vhost `vulns.toorren.net` met Authelia.
- Authelia-groep wordt `monitoring`, consistent met `status.toorren.net`.
- Server-rendered HTML per systeem/package; filters via queryparameters.
- `/vulns.json` met dezelfde data.
- Read-only SQLite-toegang tot de FreshRSS-DB (`mode=ro`, aparte user in groep `freshrss`).
- Cache in `/var/lib/vuln-radar/cache.sqlite` met ruwe bronresponses en de laatste verversing.

### 6. Eigen NixOS-inventaris uit de flake

De flake genereert één inventory-JSON uit alle `nixosConfigurations` en geeft die aan de
malandro-module mee. Dat is een build-time snapshot van de gedeclareerde versies; runtime-drift
wordt niet automatisch gedetecteerd. `vulnix` op de hosts is fase 2, behalve de reparatie van de
bestaande kapotte timer.

### 7. `vulnix` repareren, niet vervangen

De bestaande `vulnix-json.service` heeft een fout in de unit (`Missing '='`) en levert geen
JSON. Die wordt gerepareerd en als optionele bron gebruikt. Zonder vulnix blijft NVD de fallback
voor Nix-packages, met een lagere betrouwbaarheid.

## Risks / Trade-offs

- **NVD rate limit (5 req/30s zonder key)** → cache per CVE, batchverzoeken, vendor-changelog als
  fallback; nooit synchroon per paginaverzoek.
- **NVD/CPE-gaten** (nieuwe CVE's zonder `configurations`) → CNA-`affected`-data en
  vendor-changelogs gebruiken; ontbrekende data als `unknown` tonen.
- **Debian-JSON van 91 MB** → dagelijkse download, lokaal filteren, responstijd buiten de
  request-cyclus houden.
- **Distro-backports versus upstream** → distro-pakketten alleen met distro-data matchen;
  upstream alleen voor handmatige upstream-versies.
- **NixOS-drift** → build-time snapshot is de bron; de pagina toont de snapshot-/ververstijd.
- **False negatives** → onbekend tellen en tonen; een lege pagina betekent niet automatisch
  "veilig".
- **FreshRSS-schema** → alleen `entry` en `feed` lezen; read-only en met een integratietest.

## Migration Plan

1. Module en assets toevoegen; service nog niet inschakelen.
2. Inventaris-JSON genereren en met de testassets valideren.
3. Service lokaal starten en `/vulns.json` controleren.
4. nginx-vhost + Authelia-regel toevoegen; deployen.
5. Testassets controleren: nginx 1.30.7 → 0, PHP 8.3.36 → 12, Debian Apache → ±36,
   PHP 8.3.37 → 0, kernel → achter.
6. Bij problemen: vhost en service uitschakelen; FreshRSS blijft ongewijzigd.

## Open Questions

- Eerste echte klantlijst en of Ubuntu-ESM per klant bekend is.
- Docker-images als aparte assetvorm: buiten v1.
