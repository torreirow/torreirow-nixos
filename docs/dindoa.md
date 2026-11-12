# Dindoa — korfbalwedstrijden van Boaz in de agenda

De wedstrijden van Dindoa J4 komen als ICS-feed op `https://toorren.net/dindoa/` en via een Google
Apps Script in de eigen Google-agenda.

```
dindoa.nl ──(ma+do 06:00)──▶ malandro: dindoa-boaz.service ──▶ /var/www/toorren.net/dindoa/dindoa-boaz.ics
                                                                       │
                                     Google Apps Script (elk uur) ◀────┘──▶ eigen Google-agenda
```

## malandro

- De module komt uit de flake-input `dindoa` (`github:torreirow/dindoa`, `nixosModules.default`).
  De instellingen staan in `modules/dindoa.nix`: `calendars.boaz = { team = "j4"; email = ...; }`.
- `dindoa-boaz.timer` draait ma en do om 06:00 (+ max 10 min, `Persistent`).
  `dindoa-boaz.service` draait als gebruiker `dindoa` en schrijft eerst een tijdelijk bestand in
  dezelfde map, daarna `mv` (atomair).
- Mislukt een run, dan blijft de vorige ics staan en stuurt `dindoa-boaz-failure.service` een mail
  met de laatste 40 logregels naar `wvdtoorren@gmail.com`. Die gaat via postfix/SES, met als
  afzender `dindoa@malandro` → `dindoa@toorren.net`. Getest op 2026-11-12.
- Heeft het team (nog) geen gepubliceerde wedstrijden, dan eindigt de run met succes en blijft de
  vorige ics staan, zonder mail. Het programma verschijnt in blokken.
- De map `/var/www/toorren.net/dindoa` is van `dindoa:users` met 2775 (via tmpfiles). `index.html`
  (TorreiroW-stijl, naar `/jitsi`) staat er met de hand in en valt buiten de module.

```sh
sudo systemctl start dindoa-boaz            # nu draaien
journalctl -u dindoa-boaz -n 20             # resultaat
systemctl list-timers 'dindoa-*'            # volgende run
sudo systemctl start dindoa-boaz-failure    # foutmail testen
```

Nieuwe dindoa-versie: na een merge naar `main` van torreirow/dindoa eerst `nix flake update dindoa`,
dan rebuilden. Zonder die update blijft malandro op de versie uit `flake.lock`.

## Google-agenda (Apps Script)

Een URL-abonnement in Google Calendar wordt altijd een aparte, alleen-lezen agenda, en Google
ververst die maar eens per 8 à 24 uur. Daarom zet het project "Dindoa-Calendar" op
script.google.com (account `wvdtoorren@gmail.com`) de feed over in de eigen agenda. De bron staat in
`docs/dindoa/Code.gs` en `docs/dindoa/appsscript.json`.

- De trigger draait `sync` elk uur (opnieuw instellen met `installTrigger`).
- Wedstrijden worden gekoppeld op de ICS-UID (`team-datum-tegenstander@dindoa.nl`). Wijzigingen
  worden gepatcht, nieuwe wedstrijden toegevoegd, en toekomstige wedstrijden die uit de feed
  verdwijnen verwijderd. Gespeelde wedstrijden blijven staan.
- Het script raakt alleen events aan met het private extended property `dindoa=boaz`.
- Is de feed leeg of niet bereikbaar, dan breekt het script af zonder iets te wijzigen.
- Toestemming geven lukte niet in Firefox met meerdere ingelogde Google-accounts ("Something went
  wrong"). In een privévenster met alleen `wvdtoorren@gmail.com` werkte het wel.
