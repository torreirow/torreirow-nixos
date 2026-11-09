## 1. Voorbereiding

- [x] 1.1 Vrije poort verifiëren tegen `PORTS.md` (voorstel 9099) en `PORTS.md` bijwerken met de status-dashboard-entry
- [x] 1.2 Controleren of `*.toorren.net` wildcard-DNS + ACME-cert `status.toorren.net` dekt (`modules/dns`, `modules/acme.nix`)
- [x] 1.3 Detecteren welke OCI-backend actief is (`docker` vs `podman`) voor de juiste CLI in de collector

## 2. Soll-extractie (Nix)

- [x] 2.1 In `modules/status-page.nix` een `configured.json` genereren via `environment.etc."status-page/configured.json"` met `builtins.toJSON`
- [x] 2.2 OCI-containers uitlezen uit `config.virtualisation.oci-containers.containers` → `{ name, image, ports }`
- [x] 2.3 nginx-vhosts uitlezen uit `config.services.nginx.virtualHosts` → naam + best-effort upstream/type (proxyPass / static / redirect)
- [x] 2.4 Curated lijst native services als Nix-lijst opnemen (nginx, authelia, paperless, vaultwarden, grafana, postgresql, mysql, postfix, …)

## 3. Collector-service (Python stdlib)

- [x] 3.1 Python-script schrijven (via `pkgs.writers`/`writeScriptBin`) dat `configured.json` inleest
- [x] 3.2 Ist verzamelen: `docker/podman ps -a --format '{{json .}}'`, elk in try/except (Robuustheid-requirement)
- [x] 3.3 Ist verzamelen: `systemctl is-active <svc>` voor elke curated service
- [x] 3.4 Ist verzamelen: `ss -H -tlnp` → set luisterende poorten
- [x] 3.5 Merge-logica: per applicatie oordeel bepalen (gezond / kapot / orphan)
- [x] 3.6 `http.server`-handler: `/` rendert HTML-dashboard, `/status.json` levert machine-leesbare JSON
- [x] 3.7 Fallback-gedrag: bij ontbrekende databron sectie als "onbeschikbaar" tonen i.p.v. HTTP 500

## 4. Systemd-service

- [x] 4.1 `systemd.services.status-page` definiëren: bindt op `127.0.0.1:9099`
- [x] 4.2 Rechten regelen (root of `docker`-groep) voor docker-socket + systemd read-only toegang
- [x] 4.3 Hardening toepassen (`NoNewPrivileges`, `ProtectSystem`, read-only waar mogelijk)

## 5. Nginx + Authelia

- [x] 5.1 `services.nginx.virtualHosts."status.toorren.net"` met `forceSSL` + `useACMEHost "toorren.net"` + `proxyPass http://127.0.0.1:9099`
- [x] 5.2 Authelia forward-auth-blok kopiëren uit `modules/cockpit.nix` (`auth_request /authelia`, `@authelia_portal`, `/authelia`)
- [x] 5.3 Bevestigen dat geen firewall-poort voor 9099 wordt geopend

## 6. Integratie & verificatie

- [x] 6.1 Module importeren in `hosts/malandro/configuration.nix`
- [x] 6.2 `sudo nixos-rebuild switch --flake .#malandro` slaagt zonder fouten
- [x] 6.3 Verifiëren op host: `curl -s 127.0.0.1:9099/status.json | jq` toont soll×ist met oordelen
- [x] 6.4 Test "kapot": codepad geverifieerd via inspectie + de inverse (orphan-detectie werkt live: paperless compose-containers). Live container-stop overgeslagen op verzoek (draaiende server).
- [x] 6.5 Verifiëren via browser: `https://status.toorren.net` stuurt onbevoegd door naar Authelia, toont daarna het dashboard
