# Spec Delta

## Purpose

Anonieme bezoekmeting voor de publieke websites op malandro en Cloudflare Pages, zodat zichtbaar
is hoeveel bezoek er is, welke pagina's bekeken worden en uit welk land en welke stad, zonder
IP-adressen of andere persoonsgegevens te bewaren.

## ADDED Requirements

### Requirement: Bezoek wordt geteld per site
Het systeem SHALL voor elke gemeten site paginaweergaven, unieke bezoekers, sessies,
verwijzers, apparaattype en browser registreren en per site tonen in één dashboard.

#### Scenario: Paginaweergave op een malandro-site
- **WHEN** een bezoeker `https://wereldvanbegrip.nl/` opent
- **THEN** verschijnt binnen een minuut een paginaweergave voor `wereldvanbegrip.nl` in het dashboard

#### Scenario: Paginaweergave op een Cloudflare-site
- **WHEN** een bezoeker `https://recepten.toorren.net/` opent
- **THEN** verschijnt een paginaweergave voor `recepten.toorren.net` in hetzelfde dashboard

### Requirement: Land en stad zonder IP-adres
Het systeem SHALL per bezoek het land en, waar bekend, de stad bepalen. Het IP-adres van de
bezoeker MUST NOT worden opgeslagen. Er MUST geen cookie of andere identificatie in de browser
worden geplaatst.

#### Scenario: Locatie zichtbaar
- **WHEN** een bezoeker uit Nederland een gemeten site opent
- **THEN** toont het dashboard het land Nederland en, indien bepaalbaar, een stad

#### Scenario: Geen IP-adres in de database
- **WHEN** de database na een bezoek wordt doorzocht op het IP-adres van de bezoeker
- **THEN** komt dat IP-adres nergens voor

#### Scenario: Geen cookies
- **WHEN** een bezoeker een gemeten site opent
- **THEN** zet het meetscript geen cookie en geen localStorage-sleutel

### Requirement: Juiste bezoekerslocatie achter de proxy
Het systeem SHALL de locatie bepalen op het IP-adres van de bezoeker, niet op dat van nginx of
een tussenliggende proxy.

#### Scenario: Bezoek via nginx
- **WHEN** een meting via de nginx-vhost van de meetdienst binnenkomt
- **THEN** is de bepaalde locatie die van de bezoeker en niet "onbekend" of die van malandro

### Requirement: Alleen de gekozen sites worden gemeten
Het systeem SHALL precies deze sites meten: `toorren.net`, `wereldvanbegrip.nl`, `cckafe.com`, `cv-jolijn.toorren.net`,
`boaz.toorren.net`, `eghupload.toorren.net`, `noraly.toorren.net`, `devos.dutchyland.net`,
`recepten.toorren.net` en `www.stichtingwittevelden.nl`. Andere sites MUST geen meetscript
krijgen.

#### Scenario: Meetscript op een gekozen site
- **WHEN** de HTML van `https://cckafe.com/` wordt opgehaald
- **THEN** bevat die het meetscript met de site-ID van `cckafe.com`

#### Scenario: Geen meetscript op een app
- **WHEN** de HTML van `https://tasks.toorren.net/`, `https://grafana.toorren.net/` of `https://onzeovereenkomst.wereldvanbegrip.nl/` wordt opgehaald
- **THEN** bevat die geen meetscript

#### Scenario: Meting van een onbekende site
- **WHEN** een meting binnenkomt met een site-ID die niet bij een gekozen site hoort
- **THEN** wordt die niet geregistreerd

### Requirement: Dashboard alleen voor bevoegden
Het dashboard op `stats.toorren.net` SHALL alleen na inloggen via Authelia bereikbaar zijn. Het
meetscript en het meldadres MUST zonder inloggen bereikbaar blijven.

#### Scenario: Dashboard zonder inloggen
- **WHEN** iemand zonder Authelia-sessie `https://stats.toorren.net/` opent
- **THEN** wordt die doorgestuurd naar de Authelia-login

#### Scenario: Meetscript zonder inloggen
- **WHEN** een browser zonder sessie het meetscript of het meldadres aanroept
- **THEN** antwoordt de dienst zonder login-redirect

### Requirement: Meetadres valt niet op voor adblockers
Het meetscript en het meldadres MUST een neutrale naam hebben en NOT de standaardnamen
`umami.js`, `script.js` of `/api/send`.

#### Scenario: Neutrale namen
- **WHEN** de HTML van een gemeten site wordt opgehaald
- **THEN** komt de tekenreeks "umami" niet voor in de URL van het meetscript of het meldadres

### Requirement: Meten breekt de site nooit
Een gemeten site SHALL volledig werken als de meetdienst onbereikbaar is. Het script MUST
asynchroon laden en mag het tonen van de pagina niet vertragen.

#### Scenario: Meetdienst plat
- **WHEN** `stats.toorren.net` niet antwoordt en een bezoeker een gemeten site opent
- **THEN** laadt de pagina normaal en zonder foutmelding voor de bezoeker

### Requirement: Gegevens worden geback-upt
De meetgegevens SHALL in de bestaande nachtelijke backup van malandro zitten.

#### Scenario: Backup bevat de meetdatabase
- **WHEN** de nachtelijke backup is gedraaid
- **THEN** bevat de PostgreSQL-dump de database van de meetdienst
