## Why

Op malandro draaien tientallen applicaties in twee vormen — OCI/Docker-containers (wallos, docseal, invoiceplane, formrelay, …) én native NixOS-services (nginx, authelia, paperless, vaultwarden, grafana, postgres, mariadb, …). Er is geen enkel overzicht dat toont wat er *hoort* te draaien versus wat er *echt* draait. Bij incidenten (zie de sdb SATA-linkdrop van 2026-08-25, waarbij Docker plat ging) is dat verschil precies wat je in één oogopslag wilt zien: welke geconfigureerde containers zijn "dood"? Welke services luisteren niet meer?

## What Changes

- Nieuwe NixOS-module `modules/status-page.nix` (geïmporteerd in `hosts/malandro/configuration.nix`).
- Een klein bespoke service-proces (Python stdlib `http.server`) op `127.0.0.1:9099` dat **per request** de live status verzamelt (`docker ps -a`, `systemctl is-active`, `ss -tlnp`) en die afzet tegen de gedeclareerde config.
- De "soll" (gedeclareerde config) wordt bij `nixos-rebuild` gebakken naar `/etc/status-page/configured.json` uit `config.virtualisation.oci-containers.containers`, `config.services.nginx.virtualHosts` en een curated lijst native services.
- De merge van soll×ist levert per applicatie een status: **gezond** (geconfigureerd + draait), **kapot** (geconfigureerd, draait niet), **orphan** (draait, niet in config).
- Nieuwe nginx virtualHost `status.toorren.net` (forceSSL + `useACMEHost "toorren.net"`) met Authelia forward-auth, exact volgens het patroon van `modules/cockpit.nix`. Geen extra firewall-poort; het service-proces luistert alleen op localhost.
- Output beschikbaar als HTML-dashboard (`/`) én als machine-leesbare `/status.json`.
- `PORTS.md` bijgewerkt met poort 9099.

## Capabilities

### New Capabilities
- `status-dashboard`: Een geauthenticeerd overzichtsdashboard dat gedeclareerde applicaties (Docker-containers, nginx-vhosts, curated native services) afzet tegen hun live runtime-status en per applicatie een gezondheidsoordeel (gezond/kapot/orphan) toont, bereikbaar via `status.toorren.net`.

### Modified Capabilities
<!-- Geen bestaande capability-requirements wijzigen. -->

## Impact

- **Nieuw bestand:** `modules/status-page.nix` (module + Python-collector-script + nginx-vhost).
- **Gewijzigd:** `hosts/malandro/configuration.nix` (import toevoegen), `PORTS.md` (9099).
- **Runtime rechten:** het collector-proces heeft leestoegang nodig tot de Docker-socket en systemd (draait als root of in de `docker`-groep, read-only commando's). Mitigatie: alleen localhost + Authelia ervoor.
- **Afhankelijkheden:** Python 3 (al aanwezig via `python.nix`), `docker`/`podman` CLI, `iproute2` (`ss`), `systemctl`. Geen nieuwe externe services.
- **DNS/ACME:** `status.toorren.net` valt onder het bestaande `*.toorren.net` wildcard-certificaat (`useACMEHost`).
