# Design: it-tools op malandro naar eigen image

## Context

- `modules/ittools.nix` (geïmporteerd in `hosts/malandro/configuration.nix`) definieert
  `virtualisation.oci-containers.containers.it-tools` met `corentinth/it-tools:latest` en
  `ports = [ "8085:80" ]`. Een `pull`-policy is niet gezet, dus de default `missing` geldt en er wordt
  nooit opnieuw gepulld.
- nginx-vhost `ittools.toorren.net` met Authelia via `auth_request`. Er zijn twee extra locations:
  - `~* ^/assets/.*\.js$`: `sub_filter` herschrijft `//unpkg.com/figlet@1.6.0/fonts/` naar
    `/figlet-fonts/`.
  - `/figlet-fonts/`: proxy naar unpkg, **zonder** `auth_request`.
- Het sharevb-image luistert op 8080 (`PORT`), zet zelf COOP/COEP, en de ASCII-tool laadt fonts van
  `${base}figlet-fonts`. Die fonts zitten in het image. Een verwijzing naar unpkg komt niet meer voor
  in de bron.
- De pull-through mirror `registry-mirror` geldt alleen voor Docker Hub. ghcr.io wordt direct gepulld.

## Goals / Non-Goals

**Goals:**

- Een kleine, overzichtelijke diff in één module.

**Non-Goals:**

- Automatisch uitrollen van nieuwe builds (Watchtower, timer). Voorlopig doe je dat met de hand met
  een restart.
- Deze module omzetten naar een parametriseerbare optie (`services.ittools.*`).

## Decisions

### `latest` + `pull = "always"` in plaats van een vastgezette sha-tag

- *Alternatief:* `image = "ghcr.io/torreirow/it-tools:sha-abc1234"` in de Nix-config. Dat is
  volledig declaratief, en terugrollen gaat via een NixOS-generatie. Nadeel: elke it-tools-wijziging
  vraagt ook een commit en een switch in deze repo.
- Voor een persoonlijke tool weegt gemak zwaarder: een build op GHCR plus `systemctl restart
  docker-it-tools` is genoeg. Terugrollen kan in een noodgeval door tijdelijk een `sha-…`-tag in de
  config te zetten.
- `pull = "always"` haalt alleen bij een (her)start op. Een `nixos-rebuild switch` zonder wijziging
  in de container-definitie herstart niets.

### Binden aan `127.0.0.1:8085:8080`

Docker-gepubliceerde poorten omzeilen de NixOS-firewall. Met `0.0.0.0` is it-tools nu op het LAN
zonder Authelia bereikbaar. nginx praat al met `127.0.0.1:8085`, dus loopback is genoeg.
`PORTS.md` wordt daarop aangepast.

### figlet-locations verwijderen

De JS-`sub_filter` doet niets meer, want er staat geen unpkg-URL in de bundle. Hij kost wel CPU en
zet `Accept-Encoding` uit. De `/figlet-fonts/`-proxy is nu echt schadelijk: hij onderschept het pad
waarop het image zijn eigen fonts aanbiedt. Hij stuurt door naar unpkg, terwijl
`Cross-Origin-Embedder-Policy: require-corp` in de rest van de app geldt. Beide gaan eruit. Wat
overblijft is `location /` (met Authelia) plus de twee Authelia-hulplocations.

### Overige nginx-instellingen blijven

`proxy_http_version 1.1`, `X-Forwarded-*` en de Authelia-locations blijven ongewijzigd. nginx
geeft upstream-headers (COOP/COEP) standaard door. Er zijn geen `proxy_hide_header`-regels.

## Risks / Trade-offs

- [GHCR-image nog privé of nog niet gebouwd] → De container start niet: de pull faalt en
  `docker-it-tools.service` gaat op failed. Mitigatie: taak 1 controleert de anonieme pull vóór de
  switch.
- [`latest` bevat een kapotte upstream-commit] → Rollback: `image = "ghcr.io/torreirow/it-tools:sha-<vorige>"`
  plus een switch, of `docker-it-tools` herstarten na een fix in de fork.
- [Iemand gebruikt `http://malandro:8085` direct] → Werkt niet meer na deze change. Dat is bewust:
  zie Binden aan 127.0.0.1.
- [Grotere image en meer tools] → Het image is één nginx-container met statische bestanden. Het
  RAM-gebruik op de server verandert nauwelijks. De zware tools draaien in de browser.

## Migration Plan

1. Controleer dat `ghcr.io/torreirow/it-tools:latest` anoniem te pullen is (vanaf malandro).
2. Pas de module aan, test met `nixos-rebuild build --flake .#malandro`, commit en push.
3. Op malandro: `git pull && nixos-rebuild switch --flake .#malandro`.
4. Controleer de spec-scenario's.

Rollback: `git revert` plus een switch. Dan draait weer `corentinth/it-tools:latest` op `0.0.0.0:8085:80`.
