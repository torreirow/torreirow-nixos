# Tasks

## 1. Nginx-module

- [x] 1.1 Maak `modules/nginx-wouter-resume.nix` met de vhost `wouter-resume.toorren.net` (`root = "/var/www/cv-wouter"`, `forceSSL`, `useACMEHost = "toorren.net"`, `tryFiles = "$uri $uri/ =404"`, `index index.html`) en de vhost `cv-wouter.toorren.net` met een 301 naar `https://wouter-resume.toorren.net$request_uri`; verifieer de syntax met `nix-instantiate --parse modules/nginx-wouter-resume.nix`
- [x] 1.2 Importeer de module in `hosts/malandro/configuration.nix` naast `nginx-cv-jolijn.nix`; verifieer met `nix eval .#nixosConfigurations.malandro.config.services.nginx.virtualHosts."wouter-resume.toorren.net".root` dat de vhost bestaat en naar `/var/www/cv-wouter` wijst

## 2. Registratie en niet-indexeerbaarheid

- [x] 2.1 Voeg `"wouter-resume.toorren.net"` en `"cv-wouter.toorren.net"` toe aan de `vhosts`-lijst in `modules/nginx-no-http2.nix`; verifieer met `sudo nixos-rebuild dry-build --flake .#malandro` dat de assertion slaagt en met `nix eval .#nixosConfigurations.malandro.config.services.nginx.virtualHosts."cv-wouter.toorren.net".http2` dat beide op `false` staan
- [x] 2.2 Voeg `"wouter-resume.toorren.net".noindex = true` toe aan `services.aiBlocklist.sites` in `hosts/malandro/configuration.nix`; verifieer met `nix eval --json .#nixosConfigurations.malandro.config.services.nginx.virtualHosts."wouter-resume.toorren.net".extraConfig` dat `X-Robots-Tag: noindex, nofollow` erin zit en dat de locatie `= /robots.txt` bestaat
- [x] 2.3 Werk de sitetabel in `docs/ai-blocklist.md` bij met `wouter-resume.toorren.net` (sitemap nee, noindex ja); verifieer dat de regel in de tabel staat en de kolommen kloppen

## 3. Uitrol en gedragsverificatie

- [x] 3.1 Rol de configuratie uit op malandro met `sudo nixos-rebuild switch --flake .#malandro`; verifieer met `curl -sS -o /dev/null -w '%{http_code}' https://wouter-resume.toorren.net/` dat de homepage 200 geeft en met `https://wouter-resume.toorren.net/en/` dat de Engelse versie 200 geeft
- [x] 3.2 Verifieer de redirect: `curl -sSI https://cv-wouter.toorren.net/en/?bron=linkedin` geeft `301` met `Location: https://wouter-resume.toorren.net/en/?bron=linkedin`, en `http://cv-wouter.toorren.net/` komt na maximaal twee hops op de nieuwe host uit
- [x] 3.3 Verifieer de randgevallen: een onbestaand pad geeft 404, `curl -sSI https://wouter-resume.toorren.net/` bevat `X-Robots-Tag: noindex, nofollow`, `curl -A 'GPTBot/1.2'` geeft 403 en een normale browser-user-agent geeft 200
- [x] 3.4 Verifieer `robots.txt`: `curl -sS https://wouter-resume.toorren.net/robots.txt` bevat een `User-agent: *`-groep met `Disallow: /` en geen verwijzing naar een indexeerbare site

## Workflow follow-up

- buiten deze repo: zet in `wouter-cv/cv-wouter/config/_default/hugo.yaml` de `baseURL` op `https://wouter-resume.toorren.net/` en draai `release.sh`
- verifieer daarna dat canonical en `sitemap.xml` naar `wouter-resume.toorren.net` wijzen en dat de PDF-downloads werken
- archiveer de change met `/opsx-archive` zodra de deploy en de site-release zijn gecontroleerd
