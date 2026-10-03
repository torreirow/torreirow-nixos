## 1. Secrets aanmaken (handmatig, buiten nixos-rebuild)

- [x] 1.1 Kies een MariaDB-wachtwoord voor de `blocky`-gebruiker
- [x] 1.2 Maak `secrets/blocky-querylog-dsn-host.age` aan met één regel:
      `blocky:<pw>@tcp(127.0.0.1:3306)/blocky?charset=utf8mb4&parseTime=True&loc=Local`
      via `cd secrets && sudo ragenx -e blocky-querylog-dsn-host.age --ssh-dir /etc/ssh < payload`
- [x] 1.3 Maak `secrets/blocky-db-password-ui.age` aan met alleen het **platte wachtwoord**
      (blocky-ui.yml gebruikt de object-vorm met `password: file:/config/db_password`)
- [x] 1.4 Voeg recipient-regels voor beide secrets toe aan `secrets/secrets.nix`

## 2. MariaDB database + gebruiker (handmatig)

- [x] 2.1 Maak database `blocky` aan: `CREATE DATABASE blocky;`
- [x] 2.2 Maak gebruiker `blocky` aan met rechten op `blocky.*` voor zowel `localhost` als het
      Docker-bridge-bereik (`'blocky'@'%'` of `'blocky'@'172.%'`), wachtwoord = 1.1
- [x] 2.3 Verifieer bereikbaarheid vanaf de host (`mysql -h127.0.0.1 -ublocky -p blocky -e 'SELECT 1;'`)

## 3. Blocky-config-schema bepalen (vóór de module)

- [x] 3.1 Vastgesteld: blocky **0.29.0**, nieuw schema (`ports.dns`/`ports.http`,
      `upstreams.groups.default`, `blocking.denylists`/`clientGroupsBlock`, `queryLog.type/target`)
- [x] 3.2 `queryLog.target` ondersteunt `file:<pad>`-referentie → geheim buiten de nix-store;
      DSN-syntax `blocky:<pw>@tcp(<host>:3306)/blocky?charset=utf8mb4&parseTime=True&loc=Local`

## 4. Module aanmaken (modules/blocky.nix)

- [x] 4.1 `age.secrets.blocky-querylog-dsn-host` (owner root, mode 0400) +
      `age.secrets.blocky-querylog-dsn-ui` met expliciet `path`
- [x] 4.2 `services.blocky.enable = true`, `package = unstable.blocky` (0.35 — 0.29 kent geen
      `statistics`-sectie), `enableConfigCheck = false` + `settings`:
      `ports.dns = "127.0.0.1:53"`, `ports.http = "0.0.0.0:4000"`,
      upstreams Cloudflare (1.1.1.1/1.0.0.1) + Google (8.8.8.8/8.8.4.4),
      denylists StevenBlack/AdGuard/KADhosts, `prometheus.enable` + `statistics.enable`.
      queryLog: 0.x kent GEEN `file:` → config bij runtime renderen uit een systemd-credential
      (`LoadCredential = [ "querylog-dsn:<agenix-host-pad>" ]`, ExecStartPre schrijft
      `/run/blocky/config.yaml`, ExecStart `mkForce` erop)
- [x] 4.3 blocky-ui OCI container: image `ghcr.io/gabeduartem/blocky-ui` (versie-tag, geen `:latest`),
      `ports = [ "127.0.0.1:8087:3000" ]`, `--add-host=host.docker.internal:host-gateway`,
      `TZ=Europe/Amsterdam`, `BLOCKY_UI_CONFIG=/config/blocky-ui.yml`, volumes: statische
      `blocky-ui.yml` + de `-dsn-ui` agenix-secret read-only op `/config/query_log_target`
- [x] 4.4 Statische `blocky-ui.yml` (pkgs.writeText): `servers[].url = http://host.docker.internal:4000`,
      `logSources` mysql → `target: file:/config/query_log_target` (geen wachtwoord in de yaml)
- [x] 4.5 Nginx virtualHost `blocky.toorren.net`: `forceSSL`, `useACMEHost = "toorren.net"`,
      forward-auth-triple (`/` → `127.0.0.1:8087` + `auth_request`, `@authelia_portal`, `/authelia`)
      — byte-voor-byte uit `modules/ittools.nix`

## 5. Authelia-toegang (modules/authelia.nix)

- [x] 5.1 Voeg `"blocky.toorren.net"` toe aan de `domain`-lijst van de `operations`-regel
      (`policy = two_factor`, `subject = group:operations`)

## 6. Integreren in malandro

- [x] 6.1 Voeg `../../modules/blocky.nix` toe aan de imports in `hosts/malandro/configuration.nix`
- [x] 6.2 Voeg poort 8087 toe aan `PORTS.md` (blocky-ui, 127.0.0.1, Docker) + notitie 53 loopback / 4000 intern

## 7. Deployen en testen

- [x] 7.1 `nixos-rebuild build --flake .#malandro` en inspecteer de gegenereerde blocky `config.yaml`
- [x] 7.2 `sudo nixos-rebuild switch --flake .#malandro`
- [x] 7.3 Blocky draait + luistert lokaal: `dig @127.0.0.1 example.com` resolvt; een bekende
      ad-domein wordt geblokkeerd (`dig @127.0.0.1 <blocked>` → 0.0.0.0/NXDOMAIN)
- [x] 7.4 REST-API intern bereikbaar, LAN niet: vanaf host `curl 127.0.0.1:4000` OK; vanaf een
      LAN-host is 4000 dicht (firewall)
- [x] 7.5 blocky-ui container draait: `sudo docker ps | grep blocky-ui`; UI praat met de API
- [x] 7.6 Query-log in MariaDB: na enkele queries staan er rijen in database `blocky`; de UI toont ze
- [x] 7.7 `https://blocky.toorren.net` → 302 naar `auth.toorren.net`; na login (operations-lid,
      2FA) toont de UI het dashboard; een niet-operations-gebruiker krijgt 403
