## ADDED Requirements

### Requirement: linny-mcp serveert het torrlinny-corpus vanaf malandro

De linny-mcp-server SHALL op malandro draaien via de upstream `nixosModules.linny-mcp` en zijn
overlay, en het torrlinny-notitieboek serveren vanaf een eigen werkmap onder `/var/lib`.

#### Scenario: Bindt loopback, nooit publiek

- **WHEN** `services.linny-mcp` op malandro is ingeschakeld
- **THEN** de server SHALL luisteren op `127.0.0.1` en SHALL NOT een publiek adres of `0.0.0.0`
  binden; TLS termineert in de nginx op dezelfde host

#### Scenario: Corpus en state staan buiten /home

- **WHEN** het corpus geconfigureerd wordt
- **THEN** `corpusPath` en `stateDir` SHALL onder `/var/lib` liggen (niet `/home`), omdat de
  gehardende unit `ProtectHome = true` zet, en beide SHALL bestaan voordat de unit start

### Requirement: Het MCP-corpus staat los van de Hugo-build-checkout

Het corpus dat linny-mcp beschrijft SHALL een andere werkmap zijn dan de checkout van
`linny-web-build`, omdat die laatste periodiek `git reset --hard` en `git clean -fdx` uitvoert en
daarmee nog niet gepushte agent-notities zou vernietigen.

#### Scenario: Hugo-build raakt agent-notities niet

- **WHEN** de agent een document in het corpus schrijft en `linny-web-build` daarna draait
- **THEN** het document SHALL blijven bestaan, omdat `linny-web-build` een andere werkmap opruimt

#### Scenario: Convergentie loopt via GitHub

- **WHEN** een agent-notitie is gepusht naar `torreirow/torrlinny`
- **THEN** de Hugo-build SHALL die bij zijn eerstvolgende fetch oppikken en op
  `linny.toorren.net` tonen

### Requirement: Schrijfbaar corpus met bidirectionele git-sync

Het corpus SHALL schrijfbaar zijn (`readOnly = false`, `quarantine = true`) en in beide richtingen
synchroon gehouden worden met `github.com/torreirow/torrlinny` door een extern proces dat de
MCP-server niet bezit.

#### Scenario: Agent-writes komen op GitHub

- **WHEN** de MCP-server een (gequarantaineerd) document in het corpus schrijft
- **THEN** de git-sync-unit SHALL het als de service-gebruiker committen en pushen met de
  read/write deploy key

#### Scenario: Externe bewerkingen komen binnen

- **WHEN** een notitie elders bewerkt en naar `torreirow/torrlinny` gepusht is
- **THEN** de git-sync-unit SHALL die in het corpus binnenhalen

#### Scenario: Corpus wordt bij de eerste run gekloond

- **WHEN** de corpusmap nog geen git-repository bevat
- **THEN** die SHALL gekloond worden voordat de server hem serveert

### Requirement: Push met een aparte read/write deploy key

Schrijftoegang SHALL lopen via een eigen read/write deploy key per repository, versleuteld
opgeslagen, en SHALL NOT de bestaande read-only sleutel van de Hugo-build hergebruiken of omzetten.

#### Scenario: Twee sleutels met verschillende rechten

- **WHEN** de deploy keys op `torreirow/torrlinny` bekeken worden
- **THEN** er SHALL een read-only sleutel voor de Hugo-build bestaan én een aparte read/write
  sleutel voor linny-mcp, en de private helft SHALL alleen als agenix-secret bestaan

### Requirement: Agent-writes blijven begrensd tot hun eigen quarantaine

De tokens SHALL de scope `read:*,write:inbox` dragen, zodat de agent nieuwe documenten kan maken
en alleen zijn eigen nog-niet-gepromoveerde drafts kan wijzigen.

#### Scenario: Nieuw document landt in quarantaine

- **WHEN** de agent `create_doc` aanroept
- **THEN** het document SHALL de term `status: agent-draft` dragen

#### Scenario: Bestaande notitie is onaanraakbaar

- **WHEN** de agent een bestaand document zonder quarantaine-term probeert te wijzigen
- **THEN** de server SHALL dat weigeren

#### Scenario: Promoveren sluit de agent buiten

- **WHEN** de quarantaine-term met de hand van een document verwijderd is
- **THEN** de agent SHALL dat document niet meer kunnen wijzigen

### Requirement: Bearer-tokens komen uit een versleuteld bestand

Tokens SHALL alleen als bestandspad uit agenix aan de server gegeven worden; geen tokenwaarde
SHALL in een Nix-optie voorkomen.

#### Scenario: Records komen uit agenix

- **WHEN** de service geconfigureerd wordt
- **THEN** `tokensFile` SHALL naar een agenix-ontsleuteld bestand wijzen dat eigendom is van de
  service-gebruiker, en geen tokenliteral SHALL in `/nix/store` staan

#### Scenario: Onauthenticeerde verzoeken worden geweigerd

- **WHEN** een verzoek aan `/mcp` binnenkomt zonder geldig `Authorization: Bearer`-token
- **THEN** het SHALL geweigerd worden, terwijl `/healthz` zonder auth bereikbaar blijft

#### Scenario: Hercoderen zet de nieuwe scopes live

- **WHEN** het tokens-secret opnieuw versleuteld wordt en er een `switch` volgt
- **THEN** de unit SHALL herstarten, omdat de server het tokenbestand alleen bij start leest

### Requirement: De index bestaat vóór het serveren en loopt daarna mee

De deployment SHALL de corpusindex bouwen voordat `linny-mcp serve` start, en bijhouden terwijl het
corpus verandert — ook bij bewerkingen die git-sync binnenhaalt.

#### Scenario: Index gevuld voordat serve start

- **WHEN** de host opstart of opnieuw uitgerold wordt
- **THEN** een volledige `lindexer build` SHALL voltooien vóór `linny-mcp.service` start, zodat
  clients direct documenten kunnen bevragen

#### Scenario: Externe bewerking wordt doorzoekbaar

- **WHEN** een elders bewerkte notitie door git-sync binnengehaald is
- **THEN** een watcher SHALL de index herbouwen zodat die notitie via MCP vindbaar is zonder
  handmatige herindexering

#### Scenario: Index-artefacten blijven buiten de corpus-repo

- **WHEN** de index gebouwd of ververst wordt
- **THEN** de SQLite- en JSON-uitvoer SHALL in de state-directory staan en SHALL NOT als wijziging
  in de git-working-tree van het corpus verschijnen

### Requirement: Publiek HTTPS-eindpunt zonder Authelia

malandro SHALL de server fronten met een HTTPS-vhost op `linny-mcp.toorren.net`, zodat Claude
Online en Mobile hem bereiken. Die vhost SHALL GEEN Authelia-forward-auth gebruiken, omdat een
MCP-client alleen een bearer-token stuurt en geen loginredirect volgt.

#### Scenario: Publiek bereikbaar over TLS

- **WHEN** een client `https://linny-mcp.toorren.net/mcp` opvraagt
- **THEN** nginx SHALL TLS termineren met het bestaande wildcard-certificaat en het verzoek
  doorzetten naar de lokaal gebonden server

#### Scenario: Streams worden niet gebufferd

- **WHEN** het doorgezette verzoek de MCP streamable-HTTP-transport gebruikt
- **THEN** de vhost SHALL proxy-buffering uitzetten, HTTP/1.1 gebruiken en een lange read-timeout
  hanteren, zodat langlopende streams niet stallen of afgekapt worden
