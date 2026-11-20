# Vuln radar (vulns.toorren.net)

Versiebewust CVE-dashboard op malandro. Leest een gedeclareerde inventaris, matcht per
package de geïnstalleerde versie tegen distro-/vendor-data en toont alleen CVE's waarvoor
`installed < fixed` geldt. FreshRSS wordt read-only gebruikt voor titel/link/context.

## Toegang

- URL: <https://vulns.toorren.net> (Authelia-forward-auth, groep `monitoring`)
- Service: `127.0.0.1:9101`, systemd-unit `vuln-radar`
- JSON: `https://vulns.toorren.net/vulns.json`
- Data/cache: `/var/lib/vuln-radar/cache.sqlite`
- FreshRSS-DB: `/var/lib/freshrss/users/wouter/db.sqlite` (read-only)

## Asset-schema

Eén host heeft een OS/release en packages per bron. Dezelfde package in meerdere bronnen is
een configuratiefout.

```nix
services.vuln-radar.assets.malandro = {
  os = "nixos";
  release = "26.05";
  nix = {
    nginx = "1.30.7";
    php = "8.4.27";
    linux = "6.18.63";
  };
};
```

Externe of gemengde host via JSON:

```json
{
  "klant-a": {
    "os": "debian",
    "release": "trixie",
    "esm": false,
    "dpkg": { "openssl": "3.5.7-1~deb13u3" },
    "nix": { "apache2": "2.4.67", "php": "8.3.37" },
    "upstream": {}
  }
}
```

`extraAssetsFile` wijst naar zo'n JSON; `extraAssets` is dezelfde vorm als attrs (gebruikt
door de flake voor de eigen hosts).

## Bronnen en matching

| Bron | Gebruikt voor |
|---|---|
| Debian Security Tracker | `dpkg` op Debian, fixed version per release |
| Ubuntu CVE/USN-API | `dpkg` op Ubuntu, ESM-pocket gerespecteerd |
| PHP-changelog | `php` (upstream/nix), fixed per minor |
| nginx security advisories | `nginx` (upstream/nix) |
| Apache httpd advisories | `apache2`/`httpd` (upstream/nix) |
| CISA KEV | exploitatie-indicator |
| vulnix | NixOS-packages (als JSON aanwezig) |

Alleen `installed < fixed` wordt een treffer. Ontbreekt een fixed version of bron, dan gaat
het naar de teller **onbekend** en niet naar de groene lijst.

## Eigen hosts

De flake genereert bij de build de inventaris van lobos, mpenzi en farol; malandro vult zijn
eigen versies aan. Het is een snapshot van de gedeclareerde configuratie, geen runtime-scan.

## Klant toevoegen

1. Op de klant: `. /etc/os-release; echo "$ID $VERSION_CODENAME"`.
2. Package-versies: `dpkg-query -W -f='${source:Package}\t${Version}\n' | sort -u`.
3. Zet de regels om naar de `dpkg`-map in de JSON; voeg `esm` toe voor Ubuntu.
4. Valideer met `nixos-rebuild build` en daarna `/vulns.json`.

## Testassets

| Asset | Verwacht |
|---|---|
| `test-upstream` | nginx 1.30.7 → 0; PHP 8.3.36 → 13 |
| `test-debian` | PHP 8.3.37 → 0; Apache 2.4.67 → 36; kernel 6.12.74 → achter |

## Onderhoud

- Verversen: elke 6 uur; de pagina toont `last_refresh`.
- Bronfouten blijven zichtbaar; een gefaalde bron breekt de pagina niet.
- `vulnix-json.service` staat op een timer en schrijft `/var/lib/vulnix/vulnix.json`.
- Na een deploy moet de systeem-derivatie naar malandro worden gekopieerd
  (`nix copy --derivation --to ssh://wtoorren@malandro .#nixosConfigurations.malandro.config.system.build.toplevel`),
  anders kan `vulnix` de closure niet herleiden en valt de matcher terug op vendor/unknown.
- Rollback: `services.vuln-radar.enable = false;` en de vhost/Authelia-regel verwijderen.
