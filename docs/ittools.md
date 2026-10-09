# IT-Tools (ittools.toorren.net) eigen image

Eigen sharevb-fork image, container-poort 8085:8080, figlet-fonts, uitrollen/terugrollen.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-10-02 - IT-Tools naar eigen image (sharevb-fork) - LIVE EN GETEST

**Doel:** `ittools.toorren.net` van het stilgevallen `corentinth/it-tools` naar een eigen build.
OpenSpec change `ittools-own-image`, PR #95.

**Ketting:** repo `torreirow/it-tools` is een fork van `sharevb/it-tools` (default branch
`chore/all-my-stuffs`). Elke push daarop bouwt via `.github/workflows/torreirow-docker-ghcr.yml`
het image `ghcr.io/torreirow/it-tools:latest` (+ `sha-<short>`), publiek, alleen amd64. De
sharevb-workflows staan in die fork uit (repo-instelling, niet in git). Zie `FORK.md` daar.

**Doorgevoerd in `modules/ittools.nix`:**
- `image = "ghcr.io/torreirow/it-tools:latest"`, `pull = "always"`.
- `ports = [ "127.0.0.1:8085:8080" ]`. Het sharevb-image draait `nginx-unprivileged` op **8080**.
  Loopback, want Docker-poorten omzeilen de NixOS-firewall: met `0.0.0.0` was it-tools op het LAN
  bereikbaar **zonder Authelia**.
- De `sub_filter`-location (`*.js`) en de `/figlet-fonts/`-proxy naar unpkg zijn weg. Het image
  levert de figlet-fonts zelf onder `/figlet-fonts`, en de oude proxy zou die onderscheppen.
- Toegang: Authelia-regel `group:office`, `two_factor` (uit de RBAC-redesign, #96).

**Uitrollen van een nieuwe it-tools-build:** `sudo systemctl restart docker-it-tools`. Een
`nixos-rebuild switch` zonder wijziging in de container-definitie herstart hem niet. Terugrollen:
zet tijdelijk `image = "ghcr.io/torreirow/it-tools:sha-<vorige>"` en switch.

**Geverifieerd vóór de deploy:** de generatie op malandro was bit-voor-bit gelijk aan de build van
`main` (`f9b1072`). `diff -rq` tussen main en de branch: alleen `docker-it-tools.service`, nginx en
`status-page/configured.json` (image + poort).

**Gedeployed:** `nixos-rebuild switch --flake .#malandro` op `5737dca`, generatie **564**. Daarbij
werd alleen `nginx` herstart en `docker-it-tools` gestart. Live geverifieerd:
- `docker ps`: `ghcr.io/torreirow/it-tools:latest  127.0.0.1:8085->8080/tcp`
- `https://ittools.toorren.net/` → 302 naar `auth.toorren.net`
- loopback `:8085` → 200, met `Cross-Origin-Embedder-Policy: require-corp`
- vanaf de laptop op het LAN (`192.168.2.25`): `http://192.168.2.52:8085/` → timeout (`:443` wel bereikbaar)
- via een ssh-tunnel met Playwright: de argon2-hash heeft het Authelia-formaat, ASCII-art wordt
  getekend, en de fonts komen uit het image zelf (`/figlet-fonts/Standard.flf` 200), niet van unpkg
