# Tasks

## 1. Voorwaarde

- [x] 1.1 Controleer dat de it-tools-change `ghcr-docker-image` klaar is: `ssh malandro 'docker pull ghcr.io/torreirow/it-tools:latest'` slaagt zonder `docker login`

## 2. Module aanpassen

- [x] 2.1 Zet in `modules/ittools.nix` `image = "ghcr.io/torreirow/it-tools:latest"`, `pull = "always"` en `ports = [ "127.0.0.1:8085:8080" ]`. Controleer met `nix eval .#nixosConfigurations.malandro.config.virtualisation.oci-containers.containers.it-tools.ports` dat de waarde `[ "127.0.0.1:8085:8080" ]` is
- [x] 2.2 Verwijder de locations `~* ^/assets/.*\.js$` en `/figlet-fonts/` uit de vhost `ittools.toorren.net`. Controleer dat `grep -n -E 'figlet|unpkg|sub_filter' modules/ittools.nix` niets oplevert
- [x] 2.3 Werk `PORTS.md` bij (8085 → `127.0.0.1`, image sharevb-fork) en controleer de regel met `grep 8085 PORTS.md`
- [x] 2.4 Draai `nixos-rebuild build --flake .#malandro` en controleer dat de build slaagt

## 3. Deploy en verificatie

- [x] 3.1 Commit en push. Draai daarna op malandro `git pull && nixos-rebuild switch --flake .#malandro` en controleer dat `systemctl is-active docker-it-tools` `active` geeft en dat `docker ps` het ghcr-image toont
- [x] 3.2 Controleer dat `curl -sI https://ittools.toorren.net/` een 302 naar `auth.toorren.net` geeft, en dat `curl -sI http://127.0.0.1:8085/` op malandro een 200 geeft met `Cross-Origin-Embedder-Policy: require-corp`
- [x] 3.3 Controleer vanaf een ander LAN-apparaat dat `curl -m 5 http://<malandro-ip>:8085/` geweigerd wordt of een timeout geeft
- [x] 3.4 Controleer in de browser (ingelogd) dat `/argon2-hash` een `$argon2id$`-hash maakt en dat `/ascii-text-drawer` tekst tekent met fonts van `ittools.toorren.net/figlet-fonts/` (devtools → Network) (Gedaan via een ssh-tunnel naar 127.0.0.1:8085 met Playwright: argon2-hash OK, ASCII-art getekend, font van `/figlet-fonts/Standard.flf` (200), geen unpkg. Het pad met inlog via nginx en Authelia is niet automatisch getest.)
- [x] 3.5 Voeg een CHANGELOG-entry toe onder `## NEXT VERSION` en een sessie-notitie in `CLAUDE.md` (inclusief het update-commando `systemctl restart docker-it-tools`)
