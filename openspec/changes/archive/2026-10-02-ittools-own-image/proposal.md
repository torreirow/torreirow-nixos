# Proposal: it-tools op malandro naar eigen image

## Why

`modules/ittools.nix` draait `corentinth/it-tools:latest`. Upstream is sinds oktober 2024 in feite
stil blijven staan: 2 merges in 12 maanden, de laatste release is 2024.10.22. De fork
`torreirow/it-tools` is nu gebaseerd op de actieve community-fork `sharevb/it-tools`. Die heeft
ongeveer 480 tools, waaronder een argon2-hasher, en de fork krijgt eigen uitbreidingen, zoals een
argon2 verify-kaart voor Authelia-hashes. Het image daarvan staat op `ghcr.io/torreirow/it-tools`
(it-tools-change `ghcr-docker-image`).

## What Changes

- **Image** → `ghcr.io/torreirow/it-tools:latest`, met `pull = "always"`, zodat een herstart van de
  unit de nieuwste build ophaalt.
- **Containerpoort** 80 → **8080**. Het sharevb-image draait op `nginx-unprivileged`. De hostpoort
  blijft 8085.
- **Alleen gebonden aan 127.0.0.1**. Nu staat 8085 op `0.0.0.0`, en Docker zet daarvoor eigen
  iptables-regels die om de NixOS-firewall heen gaan. Daardoor is it-tools op het LAN nu zonder
  Authelia bereikbaar. **BREAKING** voor wie `http://malandro:8085` direct gebruikt: dat werkt niet
  meer, gebruik `https://ittools.toorren.net`.
- **nginx opschonen**: de `sub_filter`-location voor `*.js` en de `/figlet-fonts/`-proxy naar unpkg
  gaan eruit. Het sharevb-image levert de figlet-fonts zelf onder `/figlet-fonts`. De oude proxy zou
  die nu juist onderscheppen.
- `PORTS.md` bijwerken.

## Capabilities

### New Capabilities

- `ittools-hosting`: it-tools op malandro, achter Authelia, vanuit het eigen image.

### Modified Capabilities

(geen)

## Impact

- `modules/ittools.nix` (image, poort, pull, nginx-locations).
- `PORTS.md` (8085 → 127.0.0.1).
- Afhankelijk van: it-tools-change `ghcr-docker-image`. Het image moet publiek op GHCR staan
  voordat er gedeployd wordt.
- Deploy: `nixos-rebuild switch --flake .#malandro` op malandro.
