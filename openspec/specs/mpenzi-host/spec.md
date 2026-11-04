# mpenzi-host Specification

## Purpose
De laptop van Maaike (mpenzi): NixOS met Plasma 6 en Windows-achtige defaults, een gebruiker
zonder beheerrechten en beheer door Wouter via ssh met sleutel en een deploy vanaf lobos.

## Requirements

### Requirement: Gebruikers en rechten op mpenzi
De host mpenzi SHALL een gebruiker `maaike` hebben zonder beheerrechten (niet in `wheel`) en een
gebruiker `wtoorren` met beheerrechten (`wheel`).

#### Scenario: Maaike heeft geen sudo
- **WHEN** de configuratie van mpenzi geëvalueerd wordt
- **THEN** zit `maaike` niet in de groep `wheel`, wel in `networkmanager`, `lp` en `scanner`

#### Scenario: Wouter beheert
- **WHEN** de configuratie van mpenzi geëvalueerd wordt
- **THEN** zit `wtoorren` in `wheel`

### Requirement: SSH alleen met sleutel
mpenzi SHALL ssh aanbieden met alleen sleutel-authenticatie, zonder root-login. `wtoorren` MUST
de ssh-sleutel `wtoorren` uit `secrets/secrets.nix` als toegestane sleutel hebben.

#### Scenario: Wachtwoord geweigerd
- **WHEN** iemand met een wachtwoord via ssh inlogt
- **THEN** weigert sshd, omdat `PasswordAuthentication` en `KbdInteractiveAuthentication` uit staan

#### Scenario: Root geweigerd
- **WHEN** iemand als root via ssh inlogt
- **THEN** weigert sshd (`PermitRootLogin = no`)

### Requirement: Nederlandse taal en US-International toetsenbord
mpenzi SHALL `nl_NL.UTF-8` gebruiken voor taal en alle LC-categorieën, tijdzone
`Europe/Amsterdam`, en toetsenbordindeling `us` met variant `intl`, ook op de console.

#### Scenario: Dead keys
- **WHEN** Maaike `"` gevolgd door `e` typt
- **THEN** verschijnt `ë`, zoals op Windows US-International

### Requirement: Windows-vertrouwd bureaublad met overschrijfbare defaults
mpenzi SHALL Plasma 6 draaien met dubbelklik om te openen, Win+E voor Dolphin, Win+L om te
vergrendelen, Win+Shift+S voor een schermafbeelding van een rechthoek en Firefox als
standaardbrowser. Deze instellingen MUST systeem-defaults zijn die de gebruiker zelf kan
overschrijven.

#### Scenario: Eigen keuze blijft staan
- **WHEN** Maaike een sneltoets wijzigt en Wouter daarna opnieuw deployt
- **THEN** blijft haar wijziging staan

### Requirement: Apps en zelf installeren
mpenzi SHALL Firefox, Chrome, OnlyOffice met Microsoft-compatibele fonts, Nextcloud (start mee bij
inloggen), Thunderbird, Zoom, Bitwarden, en Canva en Jitsi als app-venster bieden. Maaike SHALL
zelf apps uit Flathub kunnen installeren via Discover. Pakketten die nixpkgs als insecure markeert
MUST NOT geïnstalleerd worden.

#### Scenario: Flathub beschikbaar
- **WHEN** mpenzi met netwerk is opgestart
- **THEN** is de systeem-remote `flathub` aanwezig

### Requirement: Beheer op afstand vanaf lobos
mpenzi SHALL bij te werken zijn met `nixos-rebuild switch --flake .#mpenzi --target-host
wtoorren@mpenzi --sudo`, zonder automatische upgrades.

#### Scenario: Ongesigneerde closure
- **WHEN** Wouter vanaf lobos deployt
- **THEN** accepteert mpenzi de closure omdat `@wheel` een trusted user is

#### Scenario: Geen autoUpgrade
- **WHEN** de configuratie geëvalueerd wordt
- **THEN** staat `system.autoUpgrade` uit
