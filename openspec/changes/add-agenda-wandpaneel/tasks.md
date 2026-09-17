## 1. kiosk-mode plugin installeren

- [x] 1.1 Plaats `kiosk-mode` JS in `www/` op malandro (handmatig; HACS-UI headless niet mogelijk) — v14.1.0 als `www/kiosk-mode.js`
- [x] 1.2 Registreer de Lovelace-resource in `.storage/lovelace_resources` — `/local/kiosk-mode.js` (module)
- [x] 1.3 Frontend serveert de resource (http 200, 58 KB) en HA logt 0 errors — console-check gebeurt op de tablet

## 2. Read-only paneelgebruiker

- [x] 2.1 Maak HA-gebruiker `paneel` aan in groep `system-read-only` (geen admin) via `.storage/auth` + `auth_provider.homeassistant`
- [x] 2.2 `paneel` zit in `system-read-only` (geen admin); login-flow getest → auth-code afgegeven
- [x] 2.3 Bestaande admingebruiker (wtoorren) en diens dashboards onaangetast (0 errors, geen bestaande entries gewijzigd)

## 3. Agenda-dashboard (kaal, panel-view)

- [x] 3.1 Stop HA (`sudo systemctl stop docker-homeassistant.service` op malandro)
- [x] 3.2 Backups gemaakt: `*.bak-claude-20260831-165547` (auth, auth_provider.homeassistant, lovelace_dashboards, lovelace_resources)
- [x] 3.3 Nieuw dashboard `.storage/lovelace.dashboard_agenda` (panel-view, één kaart) + geregistreerd in `.storage/lovelace_dashboards` (url: dashboard-agenda)
- [x] 3.4 Native `calendar`-kaart met alle 8 kalenders (wouter, family, egh, vollebal, maaike, noraly, boas_grvb, afvalbeheer_omrin) — kleuren uit de calendar-entities zelf (kaart omgezet van calendar-card-pro na visuele review)
- [x] 3.5 Agenda-lijst 7 dagen via `initial_view: listWeek` (native 7-daagse lijst, incl. kalender-toggles)
- [x] 3.6 kiosk-mode verbergt header + zijbalk voor niet-admins via `kiosk_mode: {non_admin_settings: {kiosk: true}}` op dashboard-agenda; cache past dit app-breed toe (ook op /calendar)
- [x] 3.7 Dashboard toegankelijk voor `paneel` (`require_admin: false`); per-user sidebar-restrictie niet toegepast (cosmetisch, moot onder kiosk)

## 4. Verificatie op de HA-instance

- [x] 4.1 Start HA (`sudo systemctl start docker-homeassistant.service`) — service actief
- [x] 4.2 HA komt schoon op: frontend http 200, container up, 0 ERROR-regels, paneel-login werkt
- [ ] 4.3 Als `paneel`: laad `dashboard-agenda` (primet kiosk-cache) → bevestig kaal; open dan `/calendar` → bevestig óók kaal (geen HA-chrome) — visuele check op de tablet
- [ ] 4.4 Bevestig op `/calendar` de 7-daagse lijst + kalender-toggles + legenda; zet de weergave op lijst

## 5. Fully Kiosk op de Android-tablet (strategie A)

- [ ] 5.1 Prime de kiosk-cache (open 1× `dashboard-agenda` als paneel), zet dan Fully Kiosk start-URL = `https://homeassistant.toorren.net/calendar`
- [ ] 5.2 Zet screen-always-on, dim-schema en dagelijkse auto-reload
- [ ] 5.3 Log 1× handmatig in als `paneel` (wachtwoord: zie Vaultwarden) en bevestig dat de sessie behouden blijft
- [ ] 5.4 Herstart de tablet en bevestig dat het paneel automatisch ingelogd op de kale /calendar-lijst landt

## 6. Documentatie

- [x] 6.1 Sessie-notitie toegevoegd aan `CLAUDE.md` (opzet, strategie A, kiosk-mode, read-only user, geen entity-opschoning, backups)
