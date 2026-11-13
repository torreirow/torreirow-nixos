# Dindoa — korfbalwedstrijden van J4 in de agenda

De wedstrijden van Dindoa J4 komen als ICS-feed op `https://toorren.net/dindoa/` en via een Google
Apps Script in de eigen Google-agenda.

```
dindoa.nl ──(ma+do 06:00)──▶ malandro: dindoa-j4.service ──▶ /var/www/toorren.net/dindoa/dindoa-j4.ics
                                                                       │
                                     Google Apps Script (elk uur) ◀────┘──▶ eigen Google-agenda
```

## malandro

- De module komt uit de flake-input `dindoa` (`github:torreirow/dindoa`, `nixosModules.default`).
  De instellingen staan in `modules/dindoa.nix`: `calendars.j4 = { team = "j4"; email = ...; }`.
- `dindoa-j4.timer` draait ma en do om 06:00 (+ max 10 min, `Persistent`).
  `dindoa-j4.service` draait als gebruiker `dindoa` en schrijft eerst een tijdelijk bestand in
  dezelfde map, daarna `mv` (atomair).
- Mislukt een run, dan blijft de vorige ics staan en stuurt `dindoa-j4-failure.service` een mail
  met de laatste 40 logregels naar `wvdtoorren@gmail.com`. Die gaat via postfix/SES, met als
  afzender `dindoa@malandro` → `dindoa@toorren.net`. Getest op 2026-11-12.
- Heeft het team (nog) geen gepubliceerde wedstrijden, dan eindigt de run met succes en blijft de
  vorige ics staan, zonder mail. Het programma verschijnt in blokken.
- De map `/var/www/toorren.net/dindoa` is van `dindoa:users` met 2775 (via tmpfiles). `index.html`
  (TorreiroW-stijl, naar `/jitsi`) staat er met de hand in en valt buiten de module.

```sh
sudo systemctl start dindoa-j4            # nu draaien
journalctl -u dindoa-j4 -n 20             # resultaat
systemctl list-timers 'dindoa-*'            # volgende run
sudo systemctl start dindoa-j4-failure    # foutmail testen
```

Nieuwe dindoa-versie: na een merge naar `main` van torreirow/dindoa eerst `nix flake update dindoa`,
dan rebuilden. Zonder die update blijft malandro op de versie uit `flake.lock`.

## Google-agenda (Apps Script)

Het script doet meerdere feeds, elk naar een eigen agenda. De lijst staat bovenaan `Code.gs`:

| feed               | bron                                                          | agenda                 |
| ------------------ | ------------------------------------------------------------- | ---------------------- |
| `dindoa-j4`        | `toorren.net/dindoa/dindoa-j4.ics`                            | `primary`              |
| `pauwervoll-ma-2`  | `api.nevobo.nl/export/team/CKL8X8J/meiden-a/2/programma.ics`  | `Pauwervoll MA 2`      |

`calendar` mag `primary`, een agenda-ID of een agendanaam zijn; een onbekende naam wordt aangemaakt.
De Nevobo-feed komt van de volleybal.nl-export; de `versie`-parameter daarvan verandert de inhoud
niet (getest met een oude datum: identiek bestand), het is een cache-buster. Het script zet er zelf
een verse tijd aan.


Een URL-abonnement in Google Calendar wordt altijd een aparte, alleen-lezen agenda, en Google
ververst die maar eens per 8 à 24 uur. Daarom zet het project "Dindoa-Calendar" op
script.google.com (account `wvdtoorren@gmail.com`) de feed over in de eigen agenda. De bron staat in
`docs/dindoa/Code.gs` en `docs/dindoa/appsscript.json`.

- De trigger draait `sync` elk uur (opnieuw instellen met `installTrigger`).
- Wedstrijden worden gekoppeld op de ICS-UID (`team-datum-tegenstander@dindoa.nl`). Wijzigingen
  worden gepatcht, nieuwe wedstrijden toegevoegd, en toekomstige wedstrijden die uit de feed
  verdwijnen verwijderd. Gespeelde wedstrijden blijven staan.
- Het script raakt alleen events aan met het private extended property `dindoa=j4` (events van vóór de hernoeming worden bij de eerste sync automatisch omgezet).
- Is de feed leeg of niet bereikbaar, dan breekt het script af zonder iets te wijzigen.
- Toestemming geven lukte niet in Firefox met meerdere ingelogde Google-accounts ("Something went
  wrong"). In een privévenster met alleen `wvdtoorren@gmail.com` werkte het wel.
