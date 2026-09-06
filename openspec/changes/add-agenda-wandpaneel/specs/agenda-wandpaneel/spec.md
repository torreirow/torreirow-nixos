## Purpose

Een read-only fullscreen agenda-wandpaneel in Home Assistant dat via een toegewijde
non-admin gebruiker en een kaal kiosk-dashboard de aankomende afspraken uit de vier Remote
Calendars toont op een vaste Android-wandtablet, zonder dat er een admin-sessie aan de muur hangt.

## ADDED Requirements

### Requirement: Toegewijde non-admin paneelgebruiker

Het systeem SHALL een aparte Home Assistant gebruiker `paneel` bieden die NIET de
administrator-rol heeft, zodat het wandpaneel geen volledige controle over Home Assistant
geeft aan wie fysiek bij de tablet kan.

#### Scenario: Paneelgebruiker heeft geen adminrechten

- **WHEN** de `paneel`-gebruiker is ingelogd op de tablet
- **THEN** heeft die gebruiker geen toegang tot Instellingen/Developer Tools/beheerfuncties
- **AND** kan die gebruiker uitsluitend het agenda-dashboard bekijken

#### Scenario: Bestaande admingebruiker blijft ongewijzigd

- **WHEN** de paneelgebruiker wordt toegevoegd
- **THEN** blijft de bestaande admingebruiker en diens toegang volledig intact

### Requirement: Kaal fullscreen agenda-dashboard

Het systeem SHALL een toegewijd "Agenda"-dashboard bieden dat op de tablet volledig kaal
wordt getoond: zonder Home Assistant kopbalk en zonder zijbalk, met uitsluitend de agenda-inhoud.

#### Scenario: Paneel toont geen HA-chrome

- **WHEN** het paneel (als niet-admin `paneel`-user, met geprimede kiosk-cache) de agenda-weergave opent
- **THEN** zijn de HA-kopbalk en zijbalk niet zichtbaar
- **AND** vult de agenda-inhoud het volledige scherm

#### Scenario: Dashboard is enkel voor het paneel bedoeld

- **WHEN** het agenda-dashboard is aangemaakt
- **THEN** is het zichtbaar/beschikbaar voor de `paneel`-gebruiker
- **AND** verstoort het de bestaande dashboards van de admingebruiker niet

### Requirement: Agenda-lijst van de kalenders

Het paneel SHALL de aankomende afspraken uit de acht kalenders (Wouter, Family, EGH,
Vollebal, Maaike, Noraly, Boas Grvb, Afvalbeheer omrin) tonen als één samengevoegde
chronologische agenda-lijst voor 7 dagen vooruit, met een visueel onderscheid (kleur) per
bronkalender, en met de mogelijkheid kalenders per stuk aan/uit te zetten (via de `/calendar`-pagina
in lijst-weergave) plus een legenda.

#### Scenario: Afspraken chronologisch samengevoegd

- **WHEN** meerdere kalenders afspraken hebben in de komende periode
- **THEN** verschijnen alle afspraken in één lijst op oplopende begintijd
- **AND** is per afspraak zichtbaar uit welke kalender die komt (kleur)

#### Scenario: Nederlandse, 24-uurs weergave

- **WHEN** een afspraak wordt getoond
- **THEN** zijn datum/dag en tijd in het Nederlands en in 24-uurs notatie weergegeven

#### Scenario: Vensterduur vooruit

- **WHEN** het dashboard laadt
- **THEN** toont het de afspraken voor 7 dagen vooruit

#### Scenario: Kalenders aan/uit + legenda

- **WHEN** het paneel de `/calendar`-lijstweergave toont
- **THEN** is er per kalender een aan/uit-schakelaar en een legenda met kalendernaam + kleur
- **AND** verbergt/toont het uitzetten van een kalender diens afspraken in de lijst

### Requirement: Sessie-gebaseerde auto-login zonder auth-providerwijziging

Het paneel SHALL na een eenmalige handmatige login als `paneel`-gebruiker ingelogd blijven
doordat de browsersessie/refresh-token wordt vastgehouden. Het systeem SHALL hiervoor GEEN
`trusted_networks` of andere wijziging aan de Home Assistant auth-providers vereisen, en
SHALL blijven werken via de bestaande nginx https-URL.

#### Scenario: Ingelogd blijven na eenmalige login

- **WHEN** de `paneel`-gebruiker één keer is ingelogd op de tablet
- **THEN** blijft het paneel bij normaal gebruik en herstarts van de tablet ingelogd
- **AND** is geen herhaalde wachtwoordinvoer nodig zolang de sessie geldig blijft

#### Scenario: Geen uitsluitrisico voor de beheerder

- **WHEN** de auto-login wordt ingericht
- **THEN** wordt de `configuration.yaml` auth-providerconfiguratie niet gewijzigd
- **AND** blijft de bestaande login van de beheerder onaangetast

### Requirement: Automatisch juiste dashboard bij openen

Het systeem SHALL ervoor zorgen dat het paneel bij openen automatisch op het agenda-dashboard
uitkomt, zonder handmatige navigatie.

#### Scenario: Paneel opent direct de agenda

- **WHEN** de tablet-app (kiosk-browser) opstart of ververst
- **THEN** wordt direct de kale agenda-weergave (`/calendar`-lijst) geladen
- **AND** hoeft er niet handmatig genavigeerd te worden

### Requirement: Volleybal-kalender behouden

Het systeem SHALL de bestaande volleybal-kalender-entity intact laten. In de live-toestand is
`calendar.vollebal` de énige volleybal-kalender (de eerder veronderstelde `calendar.volleybal`
bestaat niet meer); deze entity MUST daarom NIET verwijderd worden.

#### Scenario: Volleybal-entity niet verwijderd

- **WHEN** het paneel wordt ingericht
- **THEN** blijft `calendar.vollebal` bestaan en wordt die op het paneel getoond
- **AND** wordt er geen calendar-entity verwijderd
