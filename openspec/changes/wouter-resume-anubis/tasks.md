# Tasks

## 1. Backend-vhost en routering

- [x] 1.1 Voeg in `modules/nginx-wouter-resume.nix` een lokale backend-vhost toe op `127.0.0.1:8182` met `root = "/var/www/cv-wouter"`, de bestaande `tryFiles`, de `/download`-proxy naar de Cap-broker en de 404 voor `/uploads/*.pdf`; verifieer met `nix eval .#nixosConfigurations.malandro.config.services.nginx.virtualHosts` dat de backend-root en listen-instelling kloppen.
- [x] 1.2 Haal de statische locaties uit de publieke vhost en houd daar alleen TLS/ACME en de proxy naar Anubis over; verifieer met `sudo nixos-rebuild dry-build --flake .#malandro` dat de nginx-configuratie valideert.
- [x] 1.3 Houd `/.well-known/acme-challenge/` en `/healthz` (alleen `127.0.0.1` en `::1`) vóór de Anubis-proxy; verifieer met een `curl` vanaf de host dat `/healthz` 200 geeft en vanaf een externe host niet zonder challenge bereikbaar is.

## 2. Anubis-instantie

- [x] 2.1 Definieer `services.anubis.instances.cv` op loopback-TCP (`127.0.0.1:9301`) met `TARGET = "http://127.0.0.1:8182"`; verifieer met `nix eval` dat `BIND` en `TARGET` in de configuratie staan.
- [x] 2.2 Stel de policy in op `useDefaultBotRules = false` met één catch-all-regel `.*` → `CHALLENGE`, en zet `OG_PASSTHROUGH = true` en een lage `DIFFICULTY`; verifieer het gegenereerde policy-bestand en test met een browser dat de challenge verschijnt.
- [x] 2.3 Verifieer dat Anubis alleen op `127.0.0.1:9301` luistert en niet publiek bereikbaar is (`ss -lntp` op de doelhost).

## 3. Publieke vhost

- [x] 3.1 Laat de publieke vhost alle content naar Anubis op `127.0.0.1:9301` proxien en houd de bestaande 301 voor `cv-wouter.toorren.net`; verifieer met `nix eval` dat de proxyPass naar Anubis wijst en de oude host nog 301 geeft.
- [x] 3.2 Documenteer in de modulekop de Anubis-laag, de OG-uitzondering en de rollbackroute; verifieer dat de beschrijving overeenkomt met de uiteindelijke configuratie.

## 4. Integratie en Acceptatie

- [x] 4.1 Deploy naar `malandro` en verifieer in een browser: eerste bezoek toont de challenge, daarna de homepage; een herlaadbeurt met cookie gaat direct door.
- [x] 4.2 Verifieer met `curl` zonder JavaScript dat de response geen CV-tekst bevat, en herhaal met een GPTBot/ClaudeBot-user-agent; beide mogen geen pagina-inhoud krijgen.
- [x] 4.3 Verifieer de PDF-flow: `/download` zonder Cap-token geeft 403, met Cap-token een PDF, en `/uploads/*.pdf` geeft 404.
- [x] 4.4 Verifieer OG-passthrough met een preview-user-agent dat titel/beschrijving beschikbaar zijn maar de pagina-inhoud niet.
- [x] 4.5 Verifieer certificaatvernieuwing (`systemctl start acme-toorren.net.service` of de eerstvolgende renew) en de health check vanaf de lokale host.

## Workflow follow-up

- Archiveer de change nadat de acceptatie op de doelhost is geslaagd.
- Werk indien nodig de hostingdocumentatie bij met de nieuwe bezoekersflow.
