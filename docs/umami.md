# Umami: bezoekmeting (stats.toorren.net)

Anonieme, cookieloze bezoekmeting voor de publieke websites op malandro en Cloudflare Pages.
Toont paginaweergaven, bezoekers, verwijzers, apparaat/browser en **land en stad**. IP-adressen
worden niet opgeslagen (alleen gebruikt voor de GeoIP-lookup); er is geen cookiebanner nodig.

```
bezoeker (malandro-site)    --+
bezoeker (Cloudflare-site)  --+--> <script> s.js --> stats.toorren.net /api/e --> Umami :8103 --> PostgreSQL umami
                                                    (publiek, limit_req)
jij --> stats.toorren.net (dashboard, Authelia groep monitoring + Umami-login)
```

| Onderdeel     | Waarde                                                          |
|---------------|-----------------------------------------------------------------|
| Code          | `modules/umami.nix` (NixOS-module `services.umami`, Umami 3.4.0) |
| Poort         | 127.0.0.1:8103                                                  |
| Database      | PostgreSQL `umami`, peer-auth (geen wachtwoord)                 |
| Secret        | `secrets/umami-app-secret.age` (alleen de waarde, `APP_SECRET_FILE`) |
| Script        | `https://stats.toorren.net/s.js`                                 |
| Meldadres     | `https://stats.toorren.net/api/e` (alleen POST, 60/min per IP)  |
| Dashboard     | `https://stats.toorren.net`: Authelia (groep monitoring), daarna Umami-login `admin` |
| GeoIP         | GeoLite2-City, meegeleverd door het nixpkgs-pakket              |

## Gemeten sites en website-ID's

De ID's zijn niet geheim: ze staan in elke pagina.

| Site                        | Waar       | Website-ID                             |
|-----------------------------|------------|----------------------------------------|
| toorren.net                 | malandro   | `6bdab9b3-a439-475b-aedc-d97bd11d880c` |
| wereldvanbegrip.nl          | malandro   | `39cda487-8794-4414-89fc-f7e3070f0cc1` |
| cckafe.com                  | malandro   | `9dea5922-4439-43f7-9545-d362eb9e58db` |
| cv-jolijn.toorren.net       | malandro   | `acab2514-2605-401f-a2b4-7e4713cf8e56` |
| boaz.toorren.net            | malandro   | `dbcaa556-bf85-41ed-8670-ed4af36d230c` |
| eghupload.toorren.net       | malandro   | `1e0423de-8655-4832-8956-b0dbd78f0251` |
| noraly.toorren.net          | Cloudflare | `996a6792-7fb5-46eb-847c-1180ea93584e` |
| devos.dutchyland.net        | Cloudflare | `c3210430-7896-49a8-80e3-8f39c6e1a859` |
| recepten.toorren.net        | Cloudflare | `bc2d0ef2-9432-429a-ad1c-eeff0fa42d65` |
| www.stichtingwittevelden.nl | Cloudflare | `4339753d-82c6-4dd4-af84-33b1e47037d2` |

Bewust **niet** gemeten: apps met eigen login, inlog- en API-diensten, Castopod (meet zelf),
`stwvwiki`, `opsknight`, `adresses`, alles achter Authelia, en
`onzeovereenkomst.wereldvanbegrip.nl` (DocuSeal: vertrouwelijke documenten, en de strikte CSP
met nonce blokkeert een ingevoegd script terecht).

## Hoe het script op de pagina komt

- **malandro:** nginx `sub_filter` voegt vóór `</body>` het script in (`trackedSites` in
  `modules/umami.nix`). Vóór `</body>` omdat de geminificeerde pagina van toorren.net geen
  `</head>` heeft. Proxied sites krijgen `Accept-Encoding ""` naar de backend, anders kan
  sub_filter niets. Site toevoegen: regel in `trackedSites` (+ `proxiedSites` als het een proxy is).
- **Cloudflare Pages (Hugo):** in de head-partial van de repo, alleen als `hugo.IsProduction`
  (een lokale `hugo server` telt dus niet mee):
  `dailydevos/layouts/partials/header.html`, `recepten/layouts/partials/head.html`,
  `noraly-cv/noraly-cv/layouts/partials/head.html`, `stwittevelden-website/layouts/partials/head.html`.
  Stichtingwittevelden heeft **twee** CSP's die allebei gelden: de header in `static/_headers` én
  een `<meta http-equiv>` in `layouts/partials/head.html` (met nonce). In beide staan
  `script-src` en `connect-src` nu op `https://stats.toorren.net`.
- `data-domains` in de scripttag zorgt dat kopieën van een pagina elders niet meetellen.

## Goed om te weten

- **Ondergrens:** adblockers en privacy-browsers houden een deel tegen, ook met de neutrale
  namen. Bezoekers zonder JavaScript tellen niet mee.
- **Stad** is grof: mobiel internet toont vaak de stad van de provider (vaak Amsterdam). Land is
  betrouwbaar.
- **Wachtwoord wijzigen** maakt de lopende Umami-sessie ongeldig: daarna gaf elke actie
  "Unauthorized" tot opnieuw inloggen (gezien op 30-10-2026).
- **Geen SSO met Authelia:** Umami OSS (3.4.1) kent geen OIDC of header-login; SSO zit alleen
  in Umami Cloud/Enterprise. `DISABLE_LOGIN` verbergt alleen de loginpagina. Bewust gekozen
  (30-10-2026): dubbel inloggen houden, Authelia én Umami-login met 2FA.
- **Bouwen duurt lang:** Umami (Next.js) staat niet in de binaire cache; een nieuwe versie wordt
  op malandro gebouwd (~15 min, SCHED_IDLE). Sneller: vanaf lobos bouwen met
  `nixos-rebuild switch --flake .#malandro --target-host malandro --use-remote-sudo`.

## Controle

```bash
systemctl status umami
curl -s 127.0.0.1:8103/api/heartbeat                       # {"ok":true}
# bezoeken per site met land/stad (geen IP-adressen in de database)
sudo -u postgres psql -d umami -c "select w.domain, count(*) from website_event e
  join website w using (website_id) group by w.domain order by 1"
```
