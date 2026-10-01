# Spec Delta: ittools-hosting

## Purpose

Beschrijft hoe it-tools op malandro aangeboden wordt: vanuit het eigen image van de fork, alleen
bereikbaar via `ittools.toorren.net` achter Authelia.

## ADDED Requirements

### Requirement: Eigen image

De it-tools-container op malandro SHALL draaien vanuit `ghcr.io/torreirow/it-tools:latest`. Bij elke
start van de container SHALL de nieuwste versie van die tag opgehaald worden.

#### Scenario: Na deploy

- **WHEN** de configuratie met `nixos-rebuild switch --flake .#malandro` geactiveerd is
- **THEN** toont `docker ps` de container `it-tools` met image `ghcr.io/torreirow/it-tools:latest`

#### Scenario: Nieuwe build uitrollen

- **WHEN** er een nieuw image op `latest` gepubliceerd is en `systemctl restart docker-it-tools` uitgevoerd wordt
- **THEN** draait de container het nieuwe image (de image-digest van de container is gelijk aan die van `ghcr.io/torreirow/it-tools:latest` op GHCR)

### Requirement: Alleen via Authelia bereikbaar

it-tools SHALL alleen via `https://ittools.toorren.net` bereikbaar zijn, en daar alleen na
Authelia-authenticatie. De containerpoort SHALL niet op een extern netwerkadres gepubliceerd zijn.

#### Scenario: Zonder sessie

- **WHEN** een browser zonder Authelia-sessie `https://ittools.toorren.net/` opent
- **THEN** volgt een redirect naar `https://auth.toorren.net/`

#### Scenario: Met sessie

- **WHEN** een ingelogde gebruiker `https://ittools.toorren.net/` opent
- **THEN** laadt de it-tools-startpagina

#### Scenario: Direct op de poort vanaf het LAN

- **WHEN** een ander apparaat op het LAN `http://<malandro-ip>:8085/` opent
- **THEN** wordt de verbinding geweigerd

### Requirement: Tools met WASM en eigen assets werken

De reverse proxy SHALL de headers en assets van het image ongewijzigd doorgeven, zodat tools die
WebAssembly of meegeleverde bestanden gebruiken werken.

#### Scenario: Argon2-tool

- **WHEN** een ingelogde gebruiker op `/argon2-hash` een hash maakt
- **THEN** verschijnt er een `$argon2id$`-hash
- **AND** bevatten de antwoorden van `ittools.toorren.net` de header `Cross-Origin-Embedder-Policy: require-corp`

#### Scenario: Figlet-fonts

- **WHEN** een ingelogde gebruiker de ASCII-art-tool (`/ascii-text-drawer`) gebruikt
- **THEN** wordt de tekst getekend en komen de fonts van `ittools.toorren.net/figlet-fonts/`, niet van unpkg.com
