---
# nixos-90oq
title: Tijdbewuste static HTML-slaappagina + tmpfiles-symlink
status: completed
type: task
priority: normal
created_at: 2026-10-04T20:58:22Z
updated_at: 2026-10-04T21:08:42Z
parent: nixos-pudl
---

Static HTML in de stijl van de bestaande `/errors/`-pagina's (donkere achtergrond,
Nextcloud-look), via `environment.etc."nginx-nxc/sleeping.html"` +
`systemd.tmpfiles.rules` symlink naar `/var/www/nxc/` (zie patroon in modules/nginx.nix).

Client-side JS-klok:
- Lokale tijd binnen 23:00-09:00  -> "Nextcloud slaapt, terug om 09:00".
- Erbuiten                         -> "Nextcloud is onverwacht onbereikbaar".

Puur cosmetisch welke tekst verschijnt (browser-tijd van de bezoeker); geen backend.



## Summary of Changes
Tijdbewuste static HTML via `environment.etc."nginx-nxc/sleeping.html"` + tmpfiles-symlink naar /var/www/nxc. JS-klok: h>=23||h<9 -> 'slaapt, terug om 09:00', anders 'onverwacht onbereikbaar'. Nix-escaping geverifieerd (apostrof intact, geen artifacts).
