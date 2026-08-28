## Context

Zie `proposal.md` — Why. Malandro draait een mix van OCI-containers (`virtualisation.oci-containers.containers.*`) en native services, met per applicatie meestal een nginx virtualHost `*.toorren.net`. Bestaande patronen die dit ontwerp hergebruikt:

- **Authelia forward-auth per vhost** — `modules/cockpit.nix` en `modules/authelia-nginx.nix` bevatten het exacte `auth_request /authelia` + `@authelia_portal`-patroon.
- **Wildcard TLS** — vhosts gebruiken `useACMEHost = "toorren.net"` + `forceSSL`.
- **Localhost-only backends** — services luisteren op `127.0.0.1:<poort>` en worden alleen via nginx ontsloten (bijv. cockpit 9095, wallos 8095).
- **Python al aanwezig** — via `hosts/malandro/python.nix`.

## Goals / Non-Goals

**Goals:**
- Eén module `modules/status-page.nix` die zelfstandig de collector-service, de soll-extractie en de nginx-vhost levert.
- Soll×ist-diff met drie oordelen (gezond/kapot/orphan) als kernwaarde.
- Geen nieuwe externe services of langdurige daemons met veel afhankelijkheden; stdlib-only.

**Non-Goals:**
- Geen historische data, grafieken of alerting (dat is Grafana/Prometheus-terrein — al aanwezig).
- Geen container-management (start/stop) vanuit het dashboard; puur read-only observatie.
- Geen automatische remediation van kapotte services.

## Decisions

### Beslissing 1: Soll uit Nix-eval bakken naar `/etc/status-page/configured.json`

Bij `nixos-rebuild` genereert de module met `builtins.toJSON` een bestand via `environment.etc."status-page/configured.json"`, opgebouwd uit:
- `config.virtualisation.oci-containers.containers` → `lib.mapAttrs` naar `{ name, image, ports }`.
- `config.services.nginx.virtualHosts` → naam + best-effort upstream (peuter `locations."/".proxyPass` eruit waar aanwezig; anders type "static"/"redirect").
- Een **curated lijst** native services in de module zelf (bijv. `nginx`, `authelia`, `paperless`, `vaultwarden`, `grafana`, `postgresql`, `mysql`, `postfix`).

*Waarom:* de config is de enige plek die de *bedoeling* kent. Dit lezen om een store-/etc-bestand te vullen introduceert geen recursie, want nginx wordt niet gedefinieerd op basis van dit bestand.

*Alternatief overwogen:* puur runtime introspectie (geen Nix-eval). Verworpen — dan kun je "kapot" (geconfigureerd maar dood) niet onderscheiden van "bestaat niet", en dat verschil is juist de kernwaarde.

### Beslissing 2: Curated lijst voor native services i.p.v. alle systemd-units

Native services worden expliciet opgesomd in de module (een Nix-lijst), niet automatisch uit `config.systemd.services` afgeleid.

*Waarom:* `config.systemd.services` bevat honderden units (mounts, timers, oneshots) — als inventaris onbruikbaar ruizig. Een handmatige lijst van "de applicaties die ertoe doen" is scherper en onderhoudbaar.

*Trade-off:* de lijst moet met de hand bijgehouden worden als er een native app bijkomt. Acceptabel; het zijn er weinig en ze veranderen zelden.

### Beslissing 3: Live per request via Python stdlib `http.server`

Een klein `python3`-script (via `pkgs.writers.writePython3` of een `pkgs.writeScriptBin`) draait als systemd-service op `127.0.0.1:9099` en verzamelt bij elke request:
- `docker ps -a --format '{{json .}}'` (of `podman` afhankelijk van backend) → naam + state.
- `systemctl is-active <svc>` voor elke curated service.
- `ss -H -tlnp` → set van luisterende poorten.

Merge met `configured.json`, render HTML op `/` en JSON op `/status.json`.

*Waarom:* "live per request" is de gekozen verversingsstrategie; stdlib `http.server` heeft nul externe deps en is triviaal te reviewen. De belasting is verwaarloosbaar (intern, weinig requests).

*Alternatief overwogen:* `fcgiwrap` + bash-CGI (meer nginx-plumbing, lastiger JSON), of periodieke timer → static HTML (verworpen: gebruiker koos live).

### Beslissing 4: Rechten — collector als root, alleen op localhost

De service heeft leestoegang nodig tot de Docker-socket en systemd. Hij draait als root (of `User` met `docker`-groep + `SupplementaryGroups`), maar bindt uitsluitend aan `127.0.0.1:9099` en is nooit via de firewall bereikbaar. Systemd-hardening (`ProtectSystem`, `NoNewPrivileges`, read-only waar mogelijk) beperkt de blast radius.

*Waarom:* read-only observatie vereist deze toegang; de combinatie localhost-only + Authelia-in-nginx maakt het risico beheersbaar.

### Beslissing 5: nginx-vhost kopieert het cockpit-patroon

`status.toorren.net` krijgt `forceSSL`, `useACMEHost "toorren.net"`, `proxyPass http://127.0.0.1:9099`, plus het `auth_request /authelia` + `@authelia_portal` + `/authelia`-blok exact zoals `modules/cockpit.nix`.

*Waarom:* bewezen patroon in deze repo; consistentie boven abstractie.

## Risks / Trade-offs

- **Root-service met docker/systemd-toegang** → Mitigatie: localhost-only bind, Authelia forward-auth verplicht, systemd-hardening, read-only commando's, geen firewall-poort.
- **Best-effort upstream-extractie uit vhosts** (proxyPass vs root vs redirect verschilt per vhost) → Mitigatie: onbekende/niet-proxy vhosts krijgen type-label i.p.v. te falen; dashboard blijft bruikbaar.
- **Curated native-service lijst raakt achter** → Mitigatie: documenteer in de module dat de lijst handmatig is; orphan-detectie vangt draaiende-maar-niet-gedeclareerde gevallen deels op.
- **Docker/systemd tijdelijk onbereikbaar** → Mitigatie: elke databron in een try/except; sectie markeren als "onbeschikbaar" i.p.v. HTTP 500 (zie spec-requirement Robuustheid).
- **Poortconflict 9099** → Mitigatie: verifiëren tegen `PORTS.md` bij implementatie; `PORTS.md` bijwerken.

## Migration Plan

1. `modules/status-page.nix` toevoegen en importeren in `hosts/malandro/configuration.nix`.
2. `sudo nixos-rebuild switch --flake .#malandro` → `configured.json` verschijnt in `/etc/status-page/`.
3. DNS: `status.toorren.net` verwijst al via wildcard; geen aparte record nodig indien `*.toorren.net` bestaat (verifiëren in `modules/dns`).
4. Verifiëren: `curl -s 127.0.0.1:9099/status.json | jq` op de host; daarna `https://status.toorren.net` via browser (Authelia-login).
5. Rollback: import-regel verwijderen + rebuild; module raakt niets anders aan (geen gedeelde state).

## Open Questions

- Moet `status.toorren.net` in een specifieke Authelia access-policy/groep (bijv. admins-only) vallen, of volstaat de standaard forward-auth zoals cockpit? Kan later in `modules/authelia.nix` verfijnd worden zonder de module of specs te wijzigen.
