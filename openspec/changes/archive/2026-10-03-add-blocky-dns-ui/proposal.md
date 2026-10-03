## Why

Blocky is een snelle, in Go geschreven DNS-proxy met ad-blocking. Malandro heeft momenteel
geen actieve DNS-adblocker: `modules/pihole.nix` staat uitgecommentarieerd en de Knot-module
(`modules/dns/`) wordt nergens geïmporteerd — poort 53 is vrij. Deze change zet Blocky neer als
NixOS-service (`services.blocky.enable`) met een eigen beheer-UI
([blocky-ui](https://github.com/GabeDuarteM/blocky-ui)) achter nginx + Authelia, volgens de
generieke nginx-werkwijze van deze host.

Blocky zelf heeft géén dashboard — alleen een REST-API + Prometheus-metrics. Die worden
**niet** publiek ontsloten. Het publieke oppervlak is uitsluitend de blocky-ui-container; blocky's
API en DNS blijven intern.

## What Changes

- Nieuwe NixOS module `modules/blocky.nix` met `services.blocky` (native) + blocky-ui (OCI container)
- Blocky draait **local-only**: DNS op `127.0.0.1:53`, geen LAN-firewall-opening (bewuste,
  latere cutover — dit vervangt nog niet de netwerk-DNS)
- Blocky REST-API op `0.0.0.0:4000`, firewall **niet** geopend → alleen host + Docker-bridge
  bereiken het; nooit via nginx, nooit publiek
- blocky-ui als OCI container `ghcr.io/gabeduartem/blocky-ui` op `127.0.0.1:8087`, praat met
  blocky's API via `host.docker.internal:4000`
- Query-log naar MariaDB: blocky schrijft queries naar database `blocky`; blocky-ui leest die
  als `logSource` voor de historische query-weergave. Beide lezen de MySQL-DSN via blocky's
  `file:`-prefix, zodat het wachtwoord niet in de nix-store komt en `blocky-ui.yml` statisch blijft
- Nginx virtualHost `blocky.toorren.net` met de generieke forward-auth-triple (zoals `ittools.nix`)
- Authelia `access_control`: `blocky.toorren.net` toegevoegd aan de bestaande `operations`-regel
  (`two_factor`, `group:operations`)
- Twee nieuwe agenix secrets, elk een volledige MySQL-DSN met hetzelfde wachtwoord:
  `blocky-querylog-dsn-host.age` (`127.0.0.1`, voor blocky native, geleverd via systemd
  `LoadCredential`) en `blocky-querylog-dsn-ui.age` (`host.docker.internal`, read-only in de
  blocky-ui container gemount)
- `PORTS.md` bijwerken: 8087 (blocky-ui), 53 loopback, 4000 interne API
- Import toevoegen aan `hosts/malandro/configuration.nix`

## Capabilities

### New Capabilities

- `blocky-dns`: Blocky als native NixOS DNS-adblocker, local-only op `127.0.0.1:53`, upstreams
  Cloudflare/Google, StevenBlack/AdGuard/KADhosts denylists, REST-API intern op `:4000`,
  query-log naar MariaDB
- `blocky-ui`: blocky-ui beheer-dashboard als OCI container op `127.0.0.1:8087`, bereikbaar via
  `blocky.toorren.net`, forward-auth via Authelia (`group:operations`, `two_factor`), praat met
  blocky's API + MariaDB query-log

### Modified Capabilities

- `authelia-access`: `blocky.toorren.net` toegevoegd aan de expliciete `operations`-regel in
  `access_control` (post-RBAC-redesign is elke vhost expliciet)

## Impact

- `modules/blocky.nix` — nieuw bestand (blocky + blocky-ui + nginx vhost)
- `modules/authelia.nix` — `blocky.toorren.net` aan de `operations`-regel toevoegen
- `hosts/malandro/configuration.nix` — import toevoegen
- `secrets/blocky-querylog-dsn-host.age` + `secrets/blocky-querylog-dsn-ui.age` — nieuw (MySQL-DSN's)
- `secrets/secrets.nix` — recipient-regels voor de nieuwe secrets
- MariaDB: database `blocky` + gebruiker aanmaken (geen `ensureDatabases` in deze repo)
- `PORTS.md` — poort 8087 documenteren
- Geen herstart van bestaande services vereist (nieuwe units); nginx reload
