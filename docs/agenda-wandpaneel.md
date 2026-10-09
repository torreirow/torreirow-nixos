# Agenda-wandpaneel (HA read-only kiosk-dashboard)

Android-wandpaneel met kiosk-mode, read-only user 'paneel' en het /calendar-dashboard.

> Verplaatst uit CLAUDE.md (Huidige Status) om de sessie-context slank te houden.

### Sessie 2026-08-31 - Agenda-wandpaneel (HA read-only kiosk-dashboard) - GROTENDEELS OPGELOST

**Doel:** Een vast Android-wandpaneel dat kaal/fullscreen de agenda's uit Home Assistant toont,
met een aparte read-only inlog die automatisch op het juiste dashboard landt. OpenSpec change
`add-agenda-wandpaneel`.

**Belangrijke les — ik zit op lobos, HA draait op malandro:** `/var/lib/homeassistant` op **lobos**
is een **backup-snapshot van 24-02-2026**, GEEN live data. De live HA staat op **malandro**
(`ssh malandro`, container `homeassistant`, config óók `/var/lib/homeassistant` → `/config`,
passwordless sudo). `ssh malandro` faalt zolang de **rbw-agent gelockt** is (`rbw unlock` nodig;
de malandro-key wordt door rbw geserveerd, `IdentitiesOnly yes`). Al het echte werk hieronder is
op malandro gedaan.

**Live-correctie t.o.v. het plan:** er zijn **8 kalenders**, niet 4 (wouter, family, egh, vollebal,
maaike, noraly, boas_grvb, afvalbeheer_omrin). En `calendar.volleybal` (correcte spelling) bestaat
live NIET meer — alléén `calendar.vollebal` (typo) bestaat en is de énige volleybal-agenda. De
oorspronkelijk geplande "opschoning" van `calendar.vollebal` is dus **geschrapt** (zou de agenda wissen).

**Doorgevoerd op malandro (strategie A = 1× inloggen + sessie vasthouden, geen trusted_networks):**
- **kiosk-mode** (NemesisRE v14.1.0) handmatig als `www/kiosk-mode.js` → geserveerd op
  `/local/kiosk-mode.js`, geregistreerd in `.storage/lovelace_resources` (HACS-UI headless niet
  mogelijk; updates lopen dus niet via HACS). `?kiosk` in de URL verbergt header + zijbalk.
- **Read-only user `paneel`** (groep `system-read-only`) via directe edits van `.storage/auth`
  (user + credential) en `.storage/auth_provider.homeassistant` (username + bcrypt-hash, hash
  gegenereerd via de HA-container zodat het klopt). **Wachtwoord: staat in Vaultwarden** (niet in
  git bewaren). Login-flow getest → auth-code afgegeven, werkt.
- **Dashboard** `.storage/lovelace.dashboard_agenda` (panel-view, **native `calendar`-kaart met
  `initial_view: listWeek`**, 8 kalenders), geregistreerd in `.storage/lovelace_dashboards` als
  `url_path: dashboard-agenda`, `require_admin: false`. URL: `homeassistant.toorren.net/dashboard-agenda?kiosk`.
  (Eerst calendar-card-pro; na visuele vergelijking omgezet naar de native listWeek-lijst — die
  bevalt beter én biedt in-kaart kalender-toggles. calendar-card-pro blijft geïnstalleerd, ongebruikt.)

**Werkwijze `.storage` (zoals altijd):** HA gestopt (`systemctl stop docker-homeassistant.service` —
let op: stop-job kan "canceled" tonen / HA doet er even over; poll tot `inactive/failed`), backups
`*.bak-claude-20260831-165547` van auth/auth_provider.homeassistant/lovelace_dashboards/lovelace_resources,
edits via `python3` (idempotent), HA gestart. **Geverifieerd:** HA komt schoon op (http 200, 0 errors),
paneel-login werkt, kiosk-mode.js geserveerd, resources geregistreerd.

**Toggles + legenda → `/calendar`-pagina i.p.v. kaart:** de kalender-aan/uit-checkboxes en legenda
zitten op HA's ingebouwde `/calendar`-pagina, NIET op de `calendar`-kaart (een kaart rendert alleen
de lijst). Daarom toont het paneel `/calendar` (lijst-weergave). Kaal gemaakt via kiosk-mode's
**cache**: `dashboard-agenda` kreeg `kiosk_mode: {non_admin_settings: {kiosk: true}}`; de tablet laadt
dat dashboard 1× als `paneel` (primet de localStorage-cache), waarna header+zijbalk app-breed
verborgen blijven — óók op `/calendar`. Header-hiding op `/calendar` is niet officieel ondersteund
(versie-afhankelijk) → visueel checken; evt. `hide_header`/`hide_sidebar` fijnregelen.

**Nog te doen (fysiek, buiten CLI):** Fully Kiosk Browser op de tablet: eerst 1× `dashboard-agenda`
laden als `paneel` (cache primen), dan start-URL = `https://homeassistant.toorren.net/calendar`
(lijst-weergave kiezen; onthouden per browser), screen-always-on/dim/auto-reload, en 1× inloggen als
`paneel` (sessie blijft hangen). Daarna visueel bevestigen: kaal + toggles + legenda + 8 kalenders.

**Status:** ✅ HA-kant live en getest. ⏳ Tablet-configuratie is handwerk.
