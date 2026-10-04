## 1. Snel falen (connect-timeout)

- [x] 1.1 In `modules/nextcloud-proxy.nix`, location `/`: `proxy_connect_timeout 3600s` → `3s`
- [x] 1.2 Bevestigen dat `proxy_send_timeout`/`proxy_read_timeout` op 3600s blijven staan (grote uploads)

## 2. Afvang (error_page + @sleeping)

- [x] 2.1 In location `/`: `error_page 502 503 504 =503 @sleeping;` toevoegen
- [x] 2.2 Nieuwe `internal` named location `@sleeping` met `root /var/www/nxc;`, serveert `sleeping.html`,
      zet `Retry-After 1800` en `Cache-Control no-store`
- [x] 2.3 Verifiëren dat de afvang gescoped is op deze vhost (niet in `modules/nginx.nix` commonHttpConfig)

## 3. Tijdbewuste static HTML + levering

- [x] 3.1 `environment.etc."nginx-nxc/sleeping.html"` met de HTML (stijl van de bestaande `/errors/`-pagina's)
- [x] 3.2 Client-side JS-klok: 23:00–09:00 → "slaapt, terug om 09:00"; daarbuiten → "onverwacht onbereikbaar"
- [x] 3.3 `systemd.tmpfiles.rules`: `/var/www/nxc` dir + symlink `/var/www/nxc/sleeping.html` → `/etc/nginx-nxc/sleeping.html`

## 4. Spec

- [x] 4.1 Delta-spec `specs/nextcloud-proxy/spec.md` (ADDED Requirement) met scenario's voor snel falen
      en de tijdbewuste onderhoudspagina

## 5. Bouwen & verifiëren

- [x] 5.1 `nix flake check` / `nixos-rebuild build --flake .#malandro` schoon (geen eval/build-fout)
- [x] 5.2 De nginx-config bevat `proxy_connect_timeout 3s`, `error_page ... =503 @sleeping` en de
      `@sleeping`-location met `internal` (geverifieerd in het gebouwde config-bestand)
- [x] 5.3 Regressie-check: de nxc-afvang zit níét in de gegenereerde config van andere vhosts
- [x] 5.4 Functioneel bewijs via wegwerp-nginx tegen een dode upstream: `error_page` → `@sleeping`
      levert HTTP **503** met de slaappagina-body, `Retry-After: 1800` en `Cache-Control: no-store`.
      (Nog NIET live op malandro uitgerold — productie-switch is een losse deploy-stap.)

## 6. Afronden

- [x] 6.1 CHANGELOG bijwerken onder `## NEXT VERSION`
- [x] 6.2 Committen (branch, geen self-promoting trailers) en archiveren volgens de OpenSpec-stappen
