## Purpose

Biedt een herbruikbare NixOS-module die een privé Linny-notebook-repo cloont, met de
`linny-web-theme` Hugo-module bouwt en als robuuste statische site publiceert — met minimale
one-time-config, webserver-agnostisch en zonder afhankelijkheid van een specifieke secrets-stack.

## ADDED Requirements

### Requirement: Herbruikbare module via flake-export

Het systeem SHALL een NixOS-module `linny-web` aanbieden via `nixosModules.linny-web` (en
`nixosModules.default`) uit de flake van de `linny-web-theme`-repo, bruikbaar op de ondersteunde
architecturen zonder `flake-utils`.

#### Scenario: Module importeren
- **WHEN** een gebruiker de flake als input toevoegt en `imports = [ inputs.linny-web.nixosModules.linny-web ]` zet
- **THEN** is `services.linny-web` beschikbaar en evalueert de configuratie zonder fouten

### Requirement: Minimale verplichte one-time-config

Het systeem SHALL met drie verplichte opties — `gitRepo`, `gitTokenFile` en `baseURL` — een werkende
site kunnen opzetten; alle overige opties SHALL zinnige defaults hebben.

#### Scenario: Alleen verplichte velden
- **WHEN** enkel `enable`, `gitRepo`, `gitTokenFile` en `baseURL` gezet zijn
- **THEN** evalueert de module en zijn de build-service, timer en `webRoot` correct gedefinieerd

#### Scenario: Ontbrekend verplicht veld
- **WHEN** `baseURL` (of `gitRepo`/`gitTokenFile`) niet gezet is terwijl de module enabled is
- **THEN** faalt de evaluatie met een duidelijke fout over het ontbrekende veld

### Requirement: Privé-repo clonen met fine-grained token

Het systeem SHALL de repo via HTTPS clonen/fetchen met een fine-grained token uit `gitTokenFile`,
waarbij het token NIET in de repo-URL of de proceslijst terechtkomt.

#### Scenario: Token-geauthenticeerde clone
- **WHEN** de build-service draait met een geldig `gitTokenFile`
- **THEN** wordt de privé-repo gecloond via een HTTP-`Authorization: Bearer`-header (extraheader), niet via een token-in-URL

### Requirement: Static build met de linny-web-theme

Het systeem SHALL de notities renderen met `hugo` en de theme-module (`themeModule`) ophalen via
`hugo mod get`, met de notebook-config (`configFile`, default `hugo-web.yaml`) en `--baseURL`, en
de Linny-JSON-config buiten de web-build houden (`--configDir doesnotexist`).

#### Scenario: Build produceert statische HTML
- **WHEN** de build-service een nieuwe commit verwerkt
- **THEN** genereert `hugo` statische HTML op basis van `configFile` en de opgehaalde theme-module

### Requirement: Robuuste publicatie (atomic swap + keep-last-good)

Het systeem SHALL nieuwe builds atomisch live zetten via een symlink-swap naar `webRoot`, en bij een
build-fout de vorige goede versie live houden. Oude builds SHALL gepruned worden.

#### Scenario: Half-gebouwde site nooit zichtbaar
- **WHEN** een nieuwe build loopt
- **THEN** blijft `webRoot` naar de vorige build wijzen tot de nieuwe build volledig klaar is (atomische swap)

#### Scenario: Build-fout breekt de live-site niet
- **WHEN** `hugo` faalt tijdens een rebuild
- **THEN** blijft de laatst succesvol gebouwde site via `webRoot` live (geen swap)

### Requirement: Webserver-agnostische, wereld-leesbare output zonder notitie-lek

Het systeem SHALL `webRoot` als leesbaar pad publiceren voor een willekeurige webserver, terwijl de
privé notities (de checkout) NIET wereld-leesbaar zijn.

#### Scenario: Willekeurige webserver kan serveren
- **WHEN** een webserver (nginx/apache/caddy) zijn root op `config.services.linny-web.webRoot` zet
- **THEN** kan die de gerenderde site lezen zonder lid te zijn van een specifieke groep

#### Scenario: Notities lekken niet naar andere lokale gebruikers
- **WHEN** de build gedraaid heeft
- **THEN** is de checkout-map met de ruwe notities niet wereld-leesbaar (privé), terwijl alleen de gerenderde output wereld-leesbaar is

### Requirement: Rebuild bij wijziging met change-detectie

Het systeem SHALL periodiek (interval `interval`) controleren op nieuwe commits en alleen bouwen bij
een wijziging van de git-`HEAD` of het bouw-recept.

#### Scenario: Nieuwe commit
- **WHEN** er nieuwe commits op de gevolgde branch staan
- **THEN** herbouwt de timer-gestuurde service binnen het interval de site

#### Scenario: Geen wijziging
- **WHEN** `HEAD` gelijk is aan de remote en er al een live-build met hetzelfde recept is
- **THEN** wordt de build overgeslagen

### Requirement: Optionele nginx-helper

Het systeem SHALL optioneel (`services.linny-web.nginx.enable`) zelf een nginx virtualHost met
`webRoot` als root en TLS via `useACMEHost` definiëren, zonder deze koppeling verplicht te maken.

#### Scenario: nginx-helper aan
- **WHEN** `services.linny-web.nginx = { enable = true; virtualHost = "notes.example.com"; useACMEHost = "example.com"; }`
- **THEN** bestaat er een nginx virtualHost `notes.example.com` met `root = webRoot` en forceSSL

#### Scenario: nginx-helper uit (default)
- **WHEN** `services.linny-web.nginx.enable` niet gezet is
- **THEN** definieert de module geen nginx virtualHost en blijft de webserver-koppeling aan de gebruiker
