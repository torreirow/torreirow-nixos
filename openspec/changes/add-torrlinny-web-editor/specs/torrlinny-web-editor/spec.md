## Purpose

Biedt een geauthenticeerde browser-editor op `linny.toorren.net/admin` waarmee de torrlinny-notities
(markdown-body én gestructureerde frontmatter) bewerkt en als git-commit naar `torreirow/torrlinny`
gepusht worden, zodat de bestaande read-only site automatisch herbouwt — met de git-repo als bron van waarheid.

## ADDED Requirements

### Requirement: Editor op aparte /admin-location achter Authelia

Het systeem SHALL een web-editor serveren op `linny.toorren.net/admin` via een aparte nginx-`location`
met een eigen root buiten de Hugo-build-output, achter dezelfde Authelia-gate als de read-only site.
De read-only site op `/` en de `torrlinny-build`-service/timer SHALL hierbij ongewijzigd blijven.

#### Scenario: Editor bereikbaar na login
- **WHEN** een via Authelia ingelogde gebruiker `linny.toorren.net/admin` opent
- **THEN** wordt de editor-UI geladen

#### Scenario: Niet-geauthenticeerd geblokkeerd
- **WHEN** een niet-ingelogde bezoeker `/admin` opent
- **THEN** wordt hij naar de Authelia-login doorgestuurd (geen editor-inhoud zichtbaar)

#### Scenario: Rebuild raakt de editor niet
- **WHEN** `torrlinny-build.service` een nieuwe site-build en atomic swap uitvoert
- **THEN** blijven de editor-bestanden onder `/admin` ongewijzigd bereikbaar

### Requirement: Zelf-gehoste, versie-gepinde editor-bundle

Het systeem SHALL de editor-assets (Sveltia-bundle, `index.html` en `config.yml`) lokaal serveren
op een vastgezette versie, zonder runtime-afhankelijkheid van een externe CDN.

#### Scenario: Geen externe CDN-call
- **WHEN** de editor-UI in de browser laadt
- **THEN** worden alle editor-assets vanaf `linny.toorren.net` geserveerd, niet vanaf een derde-partij-CDN

#### Scenario: Versie is vastgezet
- **WHEN** de module gebouwd is
- **THEN** wijst de geserveerde bundle naar een expliciet gepinde versie (geen `latest`)

### Requirement: Schrijftoegang via fine-grained token, read-only deploy-key ongemoeid

Het systeem SHALL het committen/pushen laten verlopen via een fine-grained GitHub Personal Access
Token met permission Contents read+write, beperkt tot uitsluitend de repo `torreirow/torrlinny`. De
token SHALL NIET in de nixos-repo of nix-store opgeslagen worden. De bestaande read-only deploy-key
van de build SHALL ongewijzigd read-only blijven.

#### Scenario: Commit met token
- **WHEN** een gebruiker in de editor een notitie opslaat met een geldige, correct-gescopete token
- **THEN** wordt een commit naar `main` van `torreirow/torrlinny` gepusht

#### Scenario: Token niet in repo/store
- **WHEN** de nixos-repo en nix-store doorzocht worden
- **THEN** komt de PAT-waarde daar niet in voor (die leeft alleen in de browser en Vaultwarden)

#### Scenario: Deploy-key blijft read-only
- **WHEN** de editor is uitgerold
- **THEN** heeft de build-deploy-key nog steeds uitsluitend leesrechten op de repo

### Requirement: Notities en frontmatter bewerkbaar via schema

Het systeem SHALL de platte notities uit `content/` als één collectie tonen en de frontmatter als
bewerkbare velden aanbieden (`title`, `crdate`, `customer`, `doctype`, `type`, `project`, `tags`,
`starred`, `archive`) naast de markdown-body. Bij opslaan SHALL het systeem bestaande frontmatter-velden
niet verliezen. De taxonomy-/overlay-indexpagina's (`_index.md` in submappen) SHALL buiten de
bewerkbare collectie vallen.

#### Scenario: Bestaande notitie bewerken
- **WHEN** een gebruiker een bestaande notitie opent
- **THEN** worden de body en de frontmatter-velden getoond en kunnen ze gewijzigd en opgeslagen worden

#### Scenario: Frontmatter blijft behouden
- **WHEN** een notitie met ingevulde frontmatter via de editor wordt opgeslagen
- **THEN** blijven alle gedeclareerde frontmatter-velden intact in het opgeslagen bestand

#### Scenario: Nieuwe notitie krijgt creatiedatum
- **WHEN** een gebruiker een nieuwe notitie aanmaakt
- **THEN** wordt `crdate` automatisch op de huidige datum gezet

#### Scenario: Overzichts-/taxonomiepagina's niet in de lijst
- **WHEN** de collectie in de editor getoond wordt
- **THEN** verschijnen de `_index.md`-taxonomy- en overzichtspagina's niet als bewerkbare notities

### Requirement: Bewerking triggert automatische rebuild

Het systeem SHALL na een via de editor gepushte commit de bestaande automatische-rebuild-keten laten
oppikken, zodat de gewijzigde notitie op de read-only site verschijnt zonder handmatige actie.

#### Scenario: Wijziging verschijnt op de site
- **WHEN** een gebruiker een notitie via de editor opslaat en pusht
- **THEN** herbouwt de bestaande timer-gestuurde service de site binnen het poll-interval met de wijziging
