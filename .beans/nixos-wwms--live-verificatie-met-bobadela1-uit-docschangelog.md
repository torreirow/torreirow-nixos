---
# nixos-wwms
title: Live verificatie met bobadela1 uit + docs/CHANGELOG
status: completed
type: task
priority: normal
created_at: 2026-10-04T20:58:23Z
updated_at: 2026-10-04T21:13:54Z
parent: nixos-pudl
---

Verificatie:
- `nixos-rebuild switch --flake .#malandro`, nginx herlaadt schoon.
- bobadela1 uit (of upstream onbereikbaar simuleren): nxc.toorren.net toont de
  slaappagina binnen ~3s i.p.v. te hangen, en geeft 502/504 door als @sleeping.
- Tekst-check: binnen slaapvenster "slaapt", erbuiten "onverwacht onbereikbaar"
  (bv. klok van de testbrowser tijdelijk verzetten).
- Regressie: een andere vhost (Paperless/Grafana) toont bij 502 NIET de nxc-pagina.

Afronden: CHANGELOG onder NEXT VERSION, OpenSpec-change archiveren.



## Summary of Changes
Geverifieerd: `nixos-rebuild build --flake .#malandro` schoon; gegenereerde nginx.conf bevat connect-timeout 3s, error_page =503 @sleeping en de internal @sleeping-location, gescoped op alleen nxc. Functioneel bewijs met wegwerp-nginx tegen dode upstream -> HTTP 503 + slaappagina + Retry-After/Cache-Control. CHANGELOG bijgewerkt onder NEXT VERSION (### Added). OpenSpec-change gearchiveerd (2026-10-04-catch-nextcloud-sleeping), nieuwe capability-spec nextcloud-proxy (Purpose ingevuld, validate groen). Niet live op malandro uitgerold (losse deploy-stap).



## Live-verificatie (productie, 2026-10-04 23:13)
Uitgerold op malandro (nixos-rebuild switch, generatie 72; nginx herstart). bobadela1 was op dat moment echt uit (nachtelijke shutdown). `curl -i https://nxc.toorren.net/` -> HTTP/2 **503**, slaappagina (2516 bytes), `retry-after: 1800`, `cache-control: no-store`. Terugval in **3.05s** (de 3s connect-timeout) i.p.v. de oude uren-hang. tmpfiles-symlink /var/www/nxc/sleeping.html aanwezig. Acceptatiecriteria dus live aangetoond in het echte slaapvenster.
