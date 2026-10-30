# Tasks

## 1. Umami-dienst op malandro

- [x] 1.1 `secrets/umami-app-secret.age` (alleen de random waarde; de module leest hem via `APP_SECRET_FILE`) aanmaken met ragenx en registreren in `secrets/secrets.nix`; verify: `ragenx -d umami-app-secret.age | wc -c` geeft de verwachte lengte, zonder de waarde te tonen
- [x] 1.2 `modules/umami.nix`: `services.umami` op 127.0.0.1 (vrije poort), PostgreSQL-database/gebruiker `umami` via peer-auth, `CLIENT_IP_HEADER=x-real-ip`, neutrale `TRACKER_SCRIPT_NAME`/`COLLECT_API_ENDPOINT`; importeren in `hosts/malandro/configuration.nix`; verify: rebuild slaagt, `systemctl is-active umami` en `curl 127.0.0.1:<poort>/api/heartbeat` geven ok
- [x] 1.3 nginx-vhost `stats.toorren.net`: script en meldadres publiek met `limit_req`, de rest achter Authelia forward-auth (groep `monitoring`, regel in de Authelia-config); verify: zonder sessie geeft `/` een redirect naar auth.toorren.net, het script en een POST naar het meldadres niet
- [x] 1.4 Eerste login: admin-wachtwoord wijzigen, de websites aanmaken (11; onzeovereenkomst daarna weer verwijderd, zie 2.3) en hun site-ID's noteren in `docs/umami.md`; verify: het dashboard toont 11 websites
- [ ] 1.5 `umami` toevoegen aan `nativeServices` in `modules/status-page.nix` en controleren dat de database in de rustic-dump zit; verify: status.toorren.net meldt umami gezond, en na een backup-run bevat de dump `CREATE DATABASE umami`
- [x] 1.6 `docs/umami.md` (opzet, wat wel/niet gemeten wordt, adblock-ondergrens, site-ID's, beheer) + indexregel in `CLAUDE.md`; verify: de docs noemen alle 10 sites met ID

## 2. Malandro-sites

- [x] 2.1 Nix-helper voor script-injectie met `sub_filter` vóór `</body>`, alleen `text/html`, met `proxy_set_header Accept-Encoding ""` voor proxied locations; verify: op één testsite (eghupload) bevat de HTML het script en werkt de pagina verder ongewijzigd
- [x] 2.2 Helper toepassen op `toorren.net`, `wereldvanbegrip.nl`, `cckafe.com`, `cv-jolijn.toorren.net`, `boaz.toorren.net`, `eghupload.toorren.net`; verify: per site bevat `curl -s https://<site>/` het script met de juiste site-ID, en `tasks.toorren.net`/`grafana.toorren.net` bevatten het niet
- [x] 2.3 Meting end-to-end: één bezoek per malandro-site vanuit een browser; verify: elke site toont een paginaweergave met land in het dashboard, en `psql umami` bevat het IP-adres van de bezoeker nergens

## 3. Cloudflare-sites

- [x] 3.1 Repo's lokaliseren (`noraly-cv`, `dailydevos`, `toorren-recepten`, `stwv-development` op Cloudflare Pages) en per repo de scriptregel in de gedeelde `<head>` zetten; verify: na de Pages-deploy bevat de HTML van `noraly.toorren.net`, `devos.dutchyland.net` en `recepten.toorren.net` het script
- [x] 3.2 `www.stichtingwittevelden.nl`: scriptregel plus CSP uitbreiden (`script-src` en `connect-src` met `https://stats.toorren.net`); verify: de CSP-header bevat stats.toorren.net en de browserconsole toont geen CSP-fout bij het laden
- [x] 3.3 Meting end-to-end voor de 4 Cloudflare-sites; verify: elke site toont een paginaweergave met land in het dashboard

## Workflow follow-up

- Na een week: controleren of land/stad zinnige waarden geven en of er spam-meldingen binnenkomen.
- De change archiveren (`/opsx:archive`), waarna `openspec/specs/website-analytics/spec.md` ontstaat.
