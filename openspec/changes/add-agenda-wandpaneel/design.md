## Context

Zie `proposal.md — Why` voor de motivatie. Relevante huidige toestand (geverifieerd op malandro):

- Home Assistant draait als container `docker-homeassistant.service`; alle runtime-config leeft in
  `/var/lib/homeassistant` (**niet** in deze nixos-repo). HA hangt achter nginx op
  `homeassistant.toorren.net`.
- **Al aanwezig**: HACS, de custom card `calendar-card-pro` (`www/community/calendar-card-pro/`),
  en de vier Remote Calendars: `calendar.wouter`, `calendar.family`, `calendar.egh`,
  `calendar.volleybal`.
- **Ontbreekt**: de HACS-frontend-plugin `kiosk-mode`.
- **Vervuiling**: een wees-entity `calendar.vollebal` (typo, zonder tweede 'l') naast de goede
  `calendar.volleybal`.
- **Vaste werkwijze in dit project**: `.storage`-JSON alleen bewerken met HA **gestopt**
  (`sudo systemctl stop docker-homeassistant.service`), anders overschrijft HA je edits met zijn
  geheugenkopie bij afsluiten. Elk bewerkt `.storage`-bestand krijgt een `.bak-claude-<datum>`-kopie.
  `automations.yaml`/YAML-config mag wél live bewerkt worden (reload/herstart pikt het op).

## Goals / Non-Goals

**Goals:**
- Kaal fullscreen agenda-wandpaneel op een Android-tablet, gevoed door de vier Remote Calendars.
- Een non-admin `paneel`-gebruiker zodat het altijd-ingelogde paneel geen HA-controle weggeeft.
- Auto-login zonder auth-provider-wijziging en zonder uitsluitrisico (strategie A).

**Non-Goals:**
- Geen `trusted_networks`/`configuration.yaml`-auth-wijziging (bewust afgewezen, zie Decisions).
- Geen tweerichtings-interactie: het paneel is read-only, bedient niets in HA.
- Geen NixOS-repo-wijziging: dit is puur HA-runtime + tablet-configuratie.
- Geen bewegingssensor/dim-automatisering via Fully Kiosk (bonus-idee, buiten scope).

## Decisions

### D1 — Presentatiekaart: native `calendar`-kaart in `listWeek` (gewijzigd na review)
Aanvankelijk `calendar-card-pro` gekozen; ná visuele vergelijking door de gebruiker gekozen voor de
**native `calendar`-kaart met `initial_view: listWeek`**. Redenen: het per-dag gegroepeerde
7-daagse lijstbeeld bevalt beter, het gebruikt de kleuren die al per calendar-entity zijn ingesteld,
en — doorslaggevend — het biedt **in-kaart kalender-toggles** (aan/uit per agenda). Bonus: geen
HACS-afhankelijkheid voor de kaart.
- *Trade-off*: de native kaart toont zijn eigen navigatiebalk (Today/pijltjes/view-knoppen); dat is
  kaart-chrome, geen HA-chrome, en blijft dus staan onder `?kiosk`. Acceptabel.
- *Alternatief afgewogen*: `calendar-card-pro` (kaler, geen knoppen, maar geen toggles en HACS-dependency).

### D2 — Fullscreen/kaal via `kiosk-mode` (HACS) + panel-view + `?kiosk`
`kiosk-mode` verbergt HA-kopbalk en zijbalk per dashboard/URL. Het dashboard wordt een
`panel`-view (één kaart, volle breedte). De Fully Kiosk start-URL bevat de `?kiosk`-parameter.
- *Alternatief afgewogen*: alleen tablet-browser-fullscreen zonder plugin → HA-kopbalk blijft
  zichtbaar. Afgewezen: gebruiker wil "volledig kaal".

### D3 — Auto-login = strategie A (sessie vasthouden), NIET trusted_networks
Fully Kiosk bewaart de HA refresh-token in localStorage; na 1× inloggen blijft het paneel ingelogd,
óók via de bestaande nginx https-URL.
- *Alternatief afgewogen — trusted_networks*: HA ziet achter nginx als bron-IP de proxy
  (localhost), niet de tablet, dus trusted_networks zou pas werken als de tablet nginx omzeilt
  (rechtstreeks `http://<lan-ip>:8123`, DHCP-reservering) óf via `use_x_forwarded_for`/`trusted_proxies`.
  Extra `configuration.yaml`-auth-wijziging brengt uitsluitrisico. Afgewezen ten faveure van de
  simpelere, proxy-vriendelijke strategie A.

### D4 — "Automatisch juiste dashboard": Fully Kiosk start-URL is leidend
De kiosk-browser opent letterlijk het agenda-dashboard, dus navigatie is niet nodig. Aanvullend
(riem naast bretels) wordt het agenda-dashboard als **profiel-default** van de `paneel`-user gezet
en qua zichtbaarheid tot die user beperkt.

### D5 — Read-only `paneel`-user (groep `system-read-only`) + dashboard-zichtbaarheid
Nieuwe user in groep `system-read-only` (geen admin, kan zelfs geen entities schakelen); het
agenda-dashboard wordt aan die user gekoppeld. Zo kan wie bij de tablet staat niets in HA bedienen.
Aangemaakt door directe `.storage/auth`- + `auth_provider.homeassistant`-edits (HA gestopt), met
een bcrypt-hash gegenereerd via de HA-container — één restart i.p.v. meerdere.

### D6 — Dashboard-locatie: nieuw dedicated dashboard, niet het bestaande `dashboard-planning`
Een apart, kaal dashboard (`lovelace.dashboard_agenda`) houdt het paneel geïsoleerd van de
bestaande admin-dashboards (`dashboard-toorren`, `dashboard-planning`) en voorkomt dat
kiosk-instellingen die dashboards raken.

### D7 — GEEN entity-opschoning (correctie na live-verificatie)
Oorspronkelijk plan: `calendar.vollebal` als typo-wees verwijderen. **Live blijkt echter dat
`calendar.volleybal` niet meer bestaat** en `calendar.vollebal` de énige volleybal-kalender is.
Verwijderen zou de agenda wissen → taak vervalt; de entity blijft ongemoeid en gaat mee op het paneel.

### D9 — Paneel toont `/calendar`-pagina; kaal via kiosk-mode-cache (gewijzigd na review)
De kalender-toggles én legenda die de gebruiker wil, zitten op HA's **ingebouwde `/calendar`-pagina**,
niet op de `calendar`-kaart (een kaart rendert alleen de lijst/rooster, zonder de "My calendars"-
checkboxes). Daarom wordt het paneel op `/calendar` gericht.
- Kaal maken: kiosk-mode werkt op dashboards, niet op ingebouwde pagina's — maar het **cachet** zijn
  instellingen in localStorage en herbruikt ze app-breed. `dashboard-agenda` krijgt daarom
  `kiosk_mode: { non_admin_settings: { kiosk: true } }`. De tablet laadt dat dashboard één keer als
  `paneel` (primet de cache); daarna blijven header + zijbalk verborgen op elke pagina, incl. `/calendar`.
- *Trade-off*: eenmalige cache-prime nodig; header-hiding op `/calendar` is niet officieel ondersteund
  (versie-afhankelijk) — visueel te verifiëren op de tablet, met `hide_header`/`hide_sidebar` als fijnregeling.
- `dashboard-agenda` (native listWeek-kaart) blijft als primer + kale fallback.

### D8 — kiosk-mode handmatig geplaatst i.p.v. via HACS-UI
HACS-installatie vereist de browser-UI; headless niet praktisch. Daarom de `kiosk-mode.js` handmatig
in `www/` gezet en de resource in `.storage/lovelace_resources` geregistreerd. Werkt identiek; alleen
toekomstige updates lopen niet via HACS (bewuste, kleine trade-off).

## Risks / Trade-offs

- **Refresh-token verloopt / localStorage gewist** → paneel vraagt opnieuw om login.
  *Mitigatie*: eenmalige her-login; token-levensduur is lang; tablet zelden wissen.
- **Token fysiek uit de tablet te extraheren** (het is per definitie een opgeslagen credential).
  *Mitigatie*: `paneel` is non-admin en read-only → beperkte blast radius; geen admin-token op de muur.
- **`.storage`-edit met draaiende HA overschreven** → wijziging verdwijnt.
  *Mitigatie*: HA stoppen vóór elke `.storage`-edit, starten erna; backups per bestand.
- **Verkeerde volleybal-entity (`vollebal`) per ongeluk in de kaart** → dubbele/lege events.
  *Mitigatie*: expliciet alleen `calendar.volleybal` configureren + de wees verwijderen.
- **kiosk-mode versie-mismatch met HA-frontend** → header verdwijnt niet.
  *Mitigatie*: installeren via HACS (compatibele release), resource registreren, hard-refresh testen.

## Migration Plan

1. Installeer `kiosk-mode` via HACS en registreer de Lovelace-resource.
2. Maak de non-admin `paneel`-gebruiker aan.
3. Stop HA → maak backups → voeg het "Agenda"-dashboard (panel-view + `calendar-card-pro` + kiosk-mode
   config) toe, verwijder `calendar.vollebal`, zet dashboard-zichtbaarheid/default voor `paneel` → start HA.
4. Verifieer in een browser (als `paneel`, met `?kiosk`) dat het scherm kaal is en de vier kalenders toont.
5. Configureer Fully Kiosk op de tablet (start-URL, screen-on, dim, auto-reload) en log 1× in als `paneel`.

**Rollback**: `.bak-claude-<datum>`-backups terugzetten (HA gestopt), `paneel`-user en het dashboard
verwijderen, `kiosk-mode`-resource deregistreren. Geen NixOS-rebuild nodig — niets in de repo gewijzigd.
