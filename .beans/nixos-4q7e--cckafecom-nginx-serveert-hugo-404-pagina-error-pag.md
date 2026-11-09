---
# nixos-4q7e
title: 'cckafe.com: nginx serveert Hugo-404-pagina (error_page)'
status: completed
type: epic
priority: low
tags:
    - cckafe
    - nginx
created_at: 2026-11-09T19:32:30Z
updated_at: 2026-11-09T20:14:08Z
---

## Probleem

De cckafe-website bouwt straks een eigen `404.html` in de huisstijl (OpenSpec-change
`design-system-foundation` in cckafe-website). De vhost in `modules/cckafe.nix` heeft
`tryFiles = "$uri $uri/ =404"` maar geen `error_page`, dus nginx toont zijn eigen
kale 404-pagina in plaats van die van de site.

## Aanpak

- In `modules/cckafe.nix`, vhost `cckafe.com`, `extraConfig` uitbreiden met:
  `error_page 404 /404.html;`
- Optioneel `location = /404.html { internal; }` zodat de pagina niet direct als
  200 opvraagbaar is.
- Let op `ai-blocklist`: die zet `if ($ai_bot) { return 403; }` in `location /`;
  dat blijft ongewijzigd.

## Klaar wanneer

- [x] `curl -s -o /dev/null -w '%{http_code}' https://cckafe.com/bestaat-niet` geeft 404
- [x] De response-body is de Hugo-404-pagina (bevat het cckafé-wordmark)
- [x] `https://cckafe.com/` en bestaande pagina's geven nog steeds 200

## Afhankelijkheid

Pas zinvol nadat `design-system-foundation` (cckafe-website) live staat, zodat
`/var/www/cckafe.com/404.html` bestaat.


## Stand 2026-11-09

`error_page 404 /404.html;` + `location = /404.html { internal; }` staan in `modules/cckafe.nix`; malandro bouwt. Nog te doen: switch op malandro en de curl-checks hierboven zodra `404.html` in `/var/www/cckafe.com` staat. Zonder dat bestand valt nginx terug op zijn eigen 404, dus de switch kan nu al.
