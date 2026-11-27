# Design

## Context

Zie `proposal.md` voor de motivatie. De site draait als statische Hugo-build op
`malandro` in `/var/www/cv-wouter`. Nginx doet TLS en ACME; de PDF's worden al
beschermd door een Cap-broker op `127.0.0.1:8787`, waarbij directe
`/uploads/*.pdf`-requests 404 geven. Er is nog geen bescherming op de HTML.

Anubis is beschikbaar in nixpkgs en heeft een NixOS-module. De module gebruikt
versie 1.28.2 uit de `unstable`-input; de 1.26.2 uit nixos-26.05 vroeg in Firefox
om een handmatige refresh voordat de challenge doorkwam. De module
draait per instantie een systemd-service met een configureerbare bot-policy.
Anubis luistert in deze opzet op loopback-TCP (`127.0.0.1:9301`), omdat de
nginx-proxy naar een Unix-socket in deze nginx-versie dubbele proxyheaders
opleverde.

## Goals / Non-Goals

**Goals:**

- Elke request naar de site via een proof-of-work-challenge laten lopen.
- Niet-browsers, scrapers en AI-crawlers zonder challenge geen content geven.
- Linkpreviews beperkt laten werken via Open Graph-passthrough.
- De bestaande Cap-bescherming voor PDF's intact laten.
- Interne health checks bereikbaar houden.

**Non-Goals:**

- Headless browsers met een echte browser-engine volledig weren.
- De CV-content, Hugo-build of `release.sh` wijzigen.
- De oude host `cv-wouter.toorren.net` anders behandelen dan de bestaande 301.
- Een CDN of externe bot-dienst introduceren.

## Decisions

### Anubis in plaats van Cloudflare of een eigen Cap-gate

Anubis is purpose-built voor dit probleem, zit in nixpkgs en heeft een
NixOS-module. Een eigen gate op basis van Cap zou een extra gate-pagina,
cookie-ondertekening en `auth_request`-service vereisen. Cloudflare zou DNS en
TLS naar een derde partij verplaatsen.

### Uitdaging voor alle user-agents

De policy gebruikt `useDefaultBotRules = false` met één catch-all-regel:

```json
{ "name": "everyone", "user_agent_regex": ".*", "action": "CHALLENGE" }
```

Zo krijgen ook browsers zonder cookie eerst een challenge. De standaardregels
zouden gewone browsers juist allowen, waardoor een scraper met browser-UA er
langs zou komen.

### Open Graph-passthrough aan

`OG_PASSTHROUGH = true` laat preview-clients alleen de OG-metadata lezen. De
pagina-inhoud en PDF's blijven achter de challenge. Dit is de enige
uitzondering op "alles uitdagen".

### Nginx splitsen in publiek en backend

De publieke vhost blijft TLS/ACME doen en proxyt alle content naar Anubis
op `127.0.0.1:9301`. Een tweede, lokale vhost op `127.0.0.1:8182` serveert de
statische root en de bestaande `/download`-proxy naar de Cap-broker. Anubis
`TARGET` wijst naar die backend.

Hierdoor kan Anubis niet omzeild worden via een directe backend-URL, en blijven
de bestaande routering en 404 voor PDF's werken.

### Cap-broker behouden

De PDF-flow blijft ongewijzigd: Anubis beschermt de site, Cap beschermt de
download. Dubbele controle is bewust; de PDF bevat het telefoonnummer.

### Uitzonderingen vóór Anubis

- `/.well-known/acme-challenge/` moet buiten Anubis blijven voor certificaten.
- `/healthz` is alleen vanaf `127.0.0.1` en `::1` bereikbaar.
- `robots.txt` en de challenge-assets van Anubis mogen zonder challenge.
- De oude host blijft een 301; daar staat geen content achter.

### Loopback-TCP in plaats van Unix-socket

Anubis bindt op `127.0.0.1:9301`; de backend op `127.0.0.1:8182`. Beide zijn
niet van buitenaf bereikbaar. Een Unix-socket gaf in deze nginx-versie dubbele
proxyheaders en daardoor een 400 van Anubis.

## Risks / Trade-offs

- **Anubis is een single point of failure** → systemd `Restart=on-failure` en
  een aparte health check; bij uitval geeft de site 5xx in plaats van content.
- **Challenge is te zwaar voor langzame telefoons** → `DIFFICULTY` laag houden
  (start op 4) en na deployment met een echte telefoon testen.
- **Linkpreviews blijven beperkt** → alleen OG-metadata; geen volledige preview.
- **Cookie gebonden aan browser/UA** → nieuwe browser betekent een nieuwe
  challenge; dat is acceptabel.
- **ACME kan breken door de proxy** → de acme-locatie expliciet vóór Anubis
  houden en na de eerste rebuild de certificaatvernieuwing testen.
- **Health check vanaf een andere host** → alleen localhost uitzonderen, anders
  wordt de uitzondering een bypass.

## Migration Plan

1. Backend-vhost toevoegen op `127.0.0.1:8080` en de huidige statische
   configuratie daarheen verplaatsen.
2. Anubis-instantie toevoegen met bovengenoemde policy en OG-passthrough.
3. Publieke vhost omzetten naar een proxy naar Anubis op `127.0.0.1:9301`; ACME- en
   health-locaties vóór de proxy houden.
4. `nixos-rebuild switch` en testen:
   - browser: challenge, daarna homepage;
   - `curl`: challenge/weigering, geen CV-tekst;
   - PDF: Cap-flow werkt na de challenge;
   - `curl` op `/uploads/*.pdf`: 404;
   - certificaatvernieuwing en health check.
5. Rollback: de wijziging in de nginx-module terugdraaien en rebuilden; Anubis
   kan dan uit blijven.
