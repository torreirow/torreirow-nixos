# Design

## Context

Zie `proposal.md` voor de motivatie. Bestaande situatie die het ontwerp bepaalt:

- `wouter-cv/cv-wouter/release.sh` bouwt met Hugo en rsynct naar
  `malandro:/var/www/cv-wouter`, daarna `chown -R nginx:nginx`. Dat pad en die
  eigenaar blijven ongewijzigd.
- De bestaande CV-vhosts (`modules/nginx-cv-jolijn.nix`, `modules/nginx-boaz.nix`)
  gebruiken dezelfde vorm: `root`, `forceSSL`, `useACMEHost = "toorren.net"`,
  `tryFiles = "$uri $uri/ =404"` en `index index.html`.
- `modules/nginx-no-http2.nix` bevat een expliciete lijst met alle vhosts en een
  assertion die de build laat falen zodra een vhost daar niet in staat.
- `modules/ai-blocklist/default.nix` accepteert per site `noindex = true`, zet dan
  `X-Robots-Tag: noindex, nofollow` en blokkeert AI-bots in `location /`.
- DNS `*.toorren.net` en het certificaat `*.toorren.net` dekken beide hostnamen al;
  er is geen ACME- of DNS-wijziging nodig.

## Goals / Non-Goals

**Goals**

- Eén nieuwe module die beide hostnamen afhandelt, in de stijl van de bestaande
  CV-modules.
- De canonieke host publiek en niet-indexeerbaar maken.
- De oude host permanent laten doorverwijzen met behoud van pad en query.

**Non-Goals**

- De Hugo-configuratie of `release.sh` in `wouter-cv` aanpassen.
- Umami-bezoekmeting toevoegen.
- De webroot verplaatsen of hernoemen.
- Authelia toevoegen: de site is bewust openbaar.

## Decisions

### Aparte module `modules/nginx-wouter-resume.nix`

Consistent met `nginx-cv-jolijn.nix` en `nginx-boaz.nix`: één module per CV-site,
geïmporteerd vanuit `hosts/malandro/configuration.nix`. Alternatief was de vhost in
`hosts/malandro/configuration.nix` zelf zetten, maar dat wijkt af van het bestaande
patroon en maakt de configuratie onoverzichtelijker.

### Twee virtuele hosts in plaats van `serverAliases`

`wouter-resume.toorren.net` en `cv-wouter.toorren.net` krijgen elk een eigen
`virtualHosts`-entry. De oude naam krijgt `locations."/" = { return = "301
https://wouter-resume.toorren.net$request_uri"; }`. Een alias op dezelfde vhost zou
een `if ($host = ...)` of `map` vereisen en is foutgevoeliger; twee serverblokken
maken de redirect expliciet en testbaar.

`forceSSL = true` op de oude host betekent voor `http://cv-wouter...` twee hops
(eerst naar https, dan naar de nieuwe host). Het eindresultaat voldoet aan de spec;
een aparte :80-only redirect is niet nodig.

### Geen `systemd.tmpfiles`-regel voor de webroot

`release.sh` maakt `/var/www/cv-wouter` zelf aan met `sudo mkdir -p` en zet de
eigenaar op `nginx:nginx`, net als bij `cv-jolijn`. Een tmpfiles-regel zou bij boot
een lege `root:root`-map kunnen aanmaken zonder inhoud en voegt niets toe. Ontbreekt
de map vóór de eerste release, dan geeft nginx 404; dat is tijdelijk en lost de
release op.

### `noindex` via de bestaande AI-blocklist

`services.aiBlocklist.sites."wouter-resume.toorren.net".noindex = true;` hergebruikt
de bestaande module: `X-Robots-Tag`, een `robots.txt` met `Disallow: /` en 403 voor
AI-bots. Geen eigen `add_header` of `robots.txt` in de vhost, zodat het gedrag gelijk
blijft aan `cv-jolijn.toorren.net`. De redirect-vhost krijgt geen `noindex`: een 301
heeft geen body om te indexeren.

### Beide namen in `nginx-no-http2.nix`

Verplicht door de bestaande assertion. Zonder registratie faalt de NixOS-build; met
registratie krijgen beide hosts `http2 = false`, consistent met de rest van de
listener.

### Certificaat en TLS

Beide hosts gebruiken `useACMEHost = "toorren.net"`, zodat ze het bestaande
wildcard-certificaat delen. Geen nieuwe certs.com."..."-entry.

## Risks / Trade-offs

- **HTML wijst nog naar `cv-wouter.toorren.net`** (canonical, sitemap, OG-tags)
  totdat `baseURL` in `wouter-cv` is aangepast en opnieuw gereleased → canonical
  wijst tijdelijk naar een redirect. Mitigatie: na de NixOS-deploy direct
  `baseURL` wijzigen en `release.sh` draaien; tot die tijd werkt de site wel.
- **Redirect-lus bij verkeerde configuratie** als de nieuwe host per ongeluk naar de
  oude zou verwijzen → niet van toepassing: de nieuwe vhost heeft geen redirect.
  Controleer na deploy met `curl -I` op beide namen.
- **Vergeten vhost in de http2-lijst** → de assertion stopt de build; dat is
  gewenst en wordt in de taken expliciet gedaan.
- **AI-blocklist-bestand bestaat nog niet bij de eerste boot** → de module heeft een
  seed-map en de timer vult de sitebestanden; tot die run kan `robots.txt` tijdelijk
  ontbreken. Zelfde gedrag als bij andere sites, geen extra maatregel.

## Migration Plan

1. Module toevoegen, importeren, http2-lijst en `aiBlocklist` bijwerken.
2. `nixos-rebuild switch` op malandro (of de gebruikelijke deploy).
3. Verifiëren: 200 op de nieuwe host, 301 op de oude host met pad/query,
   `X-Robots-Tag`, 403 voor `GPTBot`, 404 voor een onbestaand pad.
4. In `wouter-cv`: `baseURL` naar `https://wouter-resume.toorren.net/` en
   `release.sh` draaien.
5. Rollback: import uit `hosts/malandro/configuration.nix` halen en opnieuw
   deployen; de webroot en de site-repo blijven onaangetast.

## Open Questions

Geen. Umami volgt later als aparte wijziging zodra de website-ID bekend is.
