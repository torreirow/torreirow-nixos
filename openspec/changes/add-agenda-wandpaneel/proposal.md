## Why

De kalenders in Home Assistant (live 8 stuks: Wouter, Family, EGH, Vollebal, Maaike,
Noraly, Boas Grvb, Afvalbeheer omrin) zijn nu alleen zichtbaar via de generieke
`/calendar`-pagina achter een volledig admin-account.
Er is behoefte aan een vast **wandpaneel** (Android-tablet) dat continu, kaal en
fullscreen de aankomende afspraken als agenda-lijst toont — zonder dat er een altijd-open
admin-sessie aan de muur hangt die iedereen die langsloopt volledige controle over HA geeft.

## What Changes

- **Nieuwe HA-gebruiker `paneel`** (non-admin) die uitsluitend het agenda-dashboard mag zien.
- **Nieuw kaal fullscreen "Agenda"-dashboard** (panel-view) met één **native `calendar`-kaart**
  in `listWeek`-weergave die de acht kalenders toont als 7-daagse agenda-lijst met per-agenda
  kleuren én in-kaart kalender-toggles (voordeel t.o.v. calendar-card-pro).
- **`kiosk-mode` HACS-plugin installeren** (ontbreekt nog) om HA-header + zijbalk te verbergen
  → volledig kaal wandpaneel-beeld.
- **Auto-login = strategie A**: 1× inloggen als `paneel` in Fully Kiosk Browser op de tablet;
  de sessie/refresh-token wordt vastgehouden. Géén `trusted_networks` en géén auth-provider-
  wijziging in `configuration.yaml` (voorkomt uitsluitrisico en werkt via de bestaande
  nginx https-URL `homeassistant.toorren.net`).
- **Paneel toont HA's `/calendar`-pagina** (7-daagse lijst + kalender-toggles + legenda — die zitten
  op de pagina, niet op een kaart). Kaal gemaakt via kiosk-mode's **non-admin cache**: `dashboard-agenda`
  draagt een `kiosk_mode`-blok (`non_admin_settings.kiosk: true`); één keer laden primet de cache,
  waarna header+zijbalk app-breed verborgen blijven — óók op `/calendar`. `dashboard-agenda` (native
  listWeek-kaart) blijft bestaan als cache-primer + kale fallback.
- **GEEN entity-opschoning** meer: in de live-toestand (geverifieerd op malandro) bestaat
  `calendar.volleybal` niet meer — alléén `calendar.vollebal` bestaat nog en is dus de énige
  volleybal-kalender. De oorspronkelijk geplande verwijdering van `calendar.vollebal` is
  daarmee ongeldig (zou de volleybal-agenda wissen) en vervalt.

## Capabilities

### New Capabilities
- `agenda-wandpaneel`: Een read-only fullscreen agenda-wandpaneel in Home Assistant met een
  toegewijde non-admin (read-only) gebruiker, een kaal kiosk-dashboard, en een agenda-lijst van
  de acht kalenders — inclusief de auto-login-eisen.

### Modified Capabilities
<!-- Geen bestaande OpenSpec-capabilities; deze repo heeft geen spec voor de HA-runtime. -->

## Impact

- **HA-runtime op malandro** (`/var/lib/homeassistant`), NIET deze nixos-repo:
  - `.storage/*` — nieuwe read-only gebruiker (`auth` + `auth_provider.homeassistant`),
    nieuw lovelace-dashboard (`lovelace.dashboard_agenda` + `lovelace_dashboards`).
  - `www/` + `lovelace_resources` — nieuwe frontend-resource (`kiosk-mode`, handmatig geplaatst).
- **Bestaande assets** (al aanwezig): de acht `calendar.*`-entities; de native `calendar`-kaart
  (geen HACS nodig). `calendar-card-pro` blijft geïnstalleerd maar wordt hier niet gebruikt.
- **Fysiek op de tablet**: Fully Kiosk Browser-configuratie + eenmalige login (buiten deze repo).
- **Geen wijziging** aan nginx, `configuration.yaml` auth-providers, of de NixOS-config.
- **Backups**: alle bewerkte `.storage`-bestanden krijgen een `.bak-claude-<datum>`-kopie
  (HA gestopt tijdens `.storage`-edits, conform de vaste werkwijze in dit project).
