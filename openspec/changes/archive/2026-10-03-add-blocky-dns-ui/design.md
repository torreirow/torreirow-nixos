## Context

Malandro draait meerdere Docker-services via `virtualisation.oci-containers` (patroon o.a. in
`modules/ittools.nix`, `modules/wallos.nix`) achter nginx + Authelia forward-auth. De NixOS
`services.blocky` module geeft een vrije-vorm `settings`-attrset die één-op-één naar blocky's
`config.yaml` gaat (`format.generate`); dependency-ordering wordt afgeleid uit
`settings.queryLog.type`.

Relevante stand van zaken vóór deze change (geverifieerd):
- Poort 53 is vrij: `modules/pihole.nix` uitgecommentarieerd in `hosts/malandro/configuration.nix`,
  `modules/dns/` (Knot) nergens geïmporteerd, `systemd-resolved`-stub niet gebonden.
- MariaDB (`modules/mariadb.nix`) luistert al op `0.0.0.0` én de firewall staat Docker-bridge
  (`br+`) al toe op `:3306`. Dus zowel blocky (native → `127.0.0.1:3306`) als blocky-ui
  (container → `host.docker.internal:3306`) bereiken MariaDB zonder extra netwerk-config.
- MariaDB provisioneert hier **niet** declaratief (`ensureDatabases` ontbreekt) → de `blocky`
  database/gebruiker is een expliciete stap.
- Vrije poort in de 80xx-reeks: **8087** (niet in `PORTS.md`, niet gebonden).

## Goals / Non-Goals

**Goals:**
- Blocky als DNS-adblocker neerzetten, local-only (`127.0.0.1:53`), zonder de netwerk-DNS te raken
- Een beheer-UI (blocky-ui) op `blocky.toorren.net`, uitsluitend bereikbaar na Authelia
  (`group:operations`, `two_factor`)
- Historische query-log zichtbaar in de UI via MariaDB
- Consistent met bestaande OCI-container + forward-auth-modules

**Non-Goals:**
- Pi-hole vervangen als actieve LAN-resolver — dat is een latere, bewuste cutover
- Blocky's REST-API of Prometheus-metrics publiek of aan nginx ontsluiten
- DoT/DoH, DHCP, of conditioneel upstream-routing per client-groep
- Monitoring/alerting op blocky

## Decisions

### DNS local-only (geen LAN-cutover in deze change)
**Beslissing**: `settings.ports.dns = "127.0.0.1:53"`, geen firewall-regel voor `:53`.
**Rationale**: Blocky wordt gebouwd en getest zonder de netwerk-DNS te raken. Het netwerk blijft
op zijn huidige resolver tot een expliciete cutover (upstreams/denylists valideren met host-lokale
queries eerst). Kleinere blast radius.
**Alternatief overwogen**: direct `0.0.0.0:53` + firewall voor `192.168.2.0/24` (zoals Pi-hole had)
— afgewezen voor nu; bewaard als vervolgstap.

### REST-API op 0.0.0.0:4000, firewall dicht
**Beslissing**: `settings.ports.http = "0.0.0.0:4000"`; poort 4000 **niet** in de firewall openen.
**Rationale**: blocky-ui draait in een container en kan host-`127.0.0.1` niet bereiken; het praat
via `host.docker.internal:4000`. Daarom moet de API op een adres luisteren dat de Docker-bridge
ziet. Omdat de firewall default-deny is en 4000 niet geopend wordt, is de API alleen bereikbaar
vanaf de host en containers — niet vanaf het LAN, nooit via nginx. Dit eerbiedigt "geen metrics/API
ontsluiten": nginx ziet enkel de UI op 8087.
**Alternatief overwogen**: API op de Docker-bridge-gateway-IP binden (b.v. `172.17.0.1:4000`) —
fragieler (bridge-IP kan wijzigen), `0.0.0.0` + dichte firewall is robuuster en even veilig.

### blocky-ui als publiek oppervlak, generieke forward-auth
**Beslissing**: nginx `blocky.toorren.net` → `127.0.0.1:8087` met de exacte forward-auth-triple
uit `ittools.nix` (`/` + `auth_request`, `@authelia_portal`, interne `/authelia`).
**Rationale**: Blocky heeft geen eigen UI/login; forward-auth is hier correct (de UI heeft geen
eigen authenticatie). Byte-voor-byte hergebruik van een bewezen patroon.

### Authelia: operations-groep
**Beslissing**: `blocky.toorren.net` toevoegen aan de bestaande `operations`-regel in
`modules/authelia.nix` (naast cockpit/fail2ban/status/zigbee2mqtt/pdftools), `policy = two_factor`.
**Rationale**: Blocky is infra-/sysadmin-tooling; hoort in dezelfde bucket. Post-RBAC-redesign is
elke vhost expliciet — zonder regel is er geen toegang.

### Query-log naar MariaDB via `file:`-referentie (geen templating)
**Beslissing**: Zowel blocky als blocky-ui lezen de MySQL-DSN uit een bestand via blocky's
`file:`-prefix (ondersteund in 0.29 voor `queryLog.target`; blocky-ui ondersteunt hetzelfde voor
`logSources[].target`). In `settings` staat dus **geen** DSN-string, alleen `target = "file:<pad>"`.
Daardoor blijft `blocky-ui.yml` een **statisch** bestand (bevat enkel een `file:`-referentie) en is
er geen runtime-templating nodig.
**Rationale**: Het wachtwoord komt nooit in de nix-store, zonder een template-mechanisme. De UI
toont historische queries zodra blocky naar de DB schrijft.
**Alternatief overwogen**: `type = "console"`/none (geen DB) — geen log-weergave, afgewezen;
templating van config-bestanden — overbodig nu `file:` bestaat.

### Twee secrets: volledige DSN (blocky) + plat wachtwoord (blocky-ui)
**Beslissing**: Twee agenix secrets met hetzelfde wachtwoord, in de vorm die elke consument wil:
- `blocky-querylog-dsn-host.age` → volledige Go-driver-DSN
  `blocky:<pw>@tcp(127.0.0.1:3306)/blocky?charset=utf8mb4&parseTime=True&loc=Local`
  (blocky's `queryLog.target` is één string; alleen de hele target kan uit een `file:`)
- `blocky-db-password-ui.age` → **alleen het platte wachtwoord**. blocky-ui.yml gebruikt de
  object-vorm (`host/port/username/database` inline, niet geheim) met `password: file:/config/db_password`.
**Rationale**: Het DB-wachtwoord bevat een `(`. In blocky's Go-driver-DSN wordt dat letterlijk
geparsed (prima), maar een URL-vorm-DSN zou percent-encoding-twijfel geven. De object-vorm van
blocky-ui neemt het wachtwoord expliciet "plain, zonder URL-encoding" → geen encoding-valkuil.
blocky (native) bereikt MariaDB op `127.0.0.1`, de container op `host.docker.internal`.
**Alternatief overwogen**: URL-vorm-DSN voor blocky-ui met `%28` voor `(` — fragiel afhankelijk van
de parser; afgewezen.

### Secret-levering: LoadCredential (blocky) + volume-mount (blocky-ui)
**Beslissing**:
- Blocky draait met `DynamicUser = true` (vaste uid onbekend). Daarom het DSN-bestand via
  `systemd.services.blocky.serviceConfig.LoadCredential = [ "querylog-dsn:<agenix-pad>" ]`, en
  `queryLog.target = "file:/run/credentials/blocky.service/querylog-dsn"` (voorspelbaar pad,
  alleen leesbaar voor de service). Agenix-secret blijft `owner=root mode=0400`.
- blocky-ui (container): de `-dsn-ui` agenix-secret read-only in de container mounten (bv. op
  `/config/query_log_target`), en in `blocky-ui.yml` `logSources[].target = file:/config/query_log_target`.
- `services.blocky.enableConfigCheck = false`: de build-time `blocky validate` draait in een sandbox
  waar het `file:`-pad (`/run/credentials/...`) niet bestaat; de check zou dan falen.
**Rationale**: LoadCredential is de DynamicUser-veilige manier; het pad is deterministisch zodat de
statische config ernaar kan verwijzen.

## Risks / Open Issues

- **Blocky-versie: 0.35.0 uit de `unstable`-input** (nixpkgs 26.05 pint 0.29.0). Reden: de
  blocky-ui overzichtskaarten vereisen blocky's `statistics`-sectie, die pas vanaf 0.30+ bestaat
  (0.29 weigert `statistics` → "field not found"). Package-override `services.blocky.package =
  unstable.blocky`; de volledige config (ports/upstreams/blocking/prometheus/statistics/queryLog)
  is tegen 0.35 gevalideerd.
- **Blocky 0.29 ondersteunt GEEN `file:`-referentie** voor `queryLog.target` (de `file:`-docs
  golden voor "latest"); daarom wordt de config bij runtime gerenderd met de DSN uit een
  systemd-credential (zie de secret-levering-beslissing). Geldt ook voor 0.35.
- Schema (0.35): `ports.dns`/`ports.http`, `upstreams.groups.default`,
  `blocking.denylists`/`clientGroupsBlock`, `prometheus.enable`, `statistics.enable`,
  `queryLog.type/target`.
- **blocky-ui.yml veldnamen** (`servers[].url`, `logSources[].type/target`) tegen de gepinde
  image-tag. Pin een versie-tag i.p.v. `:latest` voor reproduceerbaarheid.
- **MariaDB-tabel**: nagaan of blocky de query-log-tabel zelf aanmaakt bij eerste write, of dat
  een schema vereist is. Gebruiker `blocky` krijgt rechten op database `blocky`.
- **Container → host.docker.internal**: vereist `--add-host=host.docker.internal:host-gateway`
  (patroon uit `invoiceplane`/`wallos`).
