# Tasks

## 1. Melding en contactadres

- [x] 1.1 Laat MKCOL en PUT in `main.go` bij een verbindingsfout of HTTP 502/503/504 een `errStorageDown` teruggeven. `fail()` antwoordt daarop met 503 en de nachtmelding. Controle: een test met een fake backend die 503 geeft (bij MKCOL en bij PUT) krijgt 503 en een melding met "23:00" en "09:00".
- [x] 1.2 Laat de melding over een onbereikbare opslag en de algemene opslagfout allebei eindigen met "Gebeurt dit opnieuw? Neem dan contact op via <contact>." Controle: een test met een fake backend die 500 geeft krijgt 502 en een melding met het contactadres. De test van 1.1 controleert ook op het contactadres.
- [x] 1.3 Beschrijf in `docs/filedrop.md` de twee meldingen en waarom de klok niet meetelt. Controle: de tekst in de doc komt overeen met de meldingen in `main.go`.
- [x] 1.4 Zet in de foutdialoog een kleine "klik hier"-mailto-link achter een melding die het contactadres noemt, en lever Roboto (Regular/Bold/Italic, Latijnse subset, OFL) mee in de binary met `/fonts/roboto-*.woff2`. Controle: `TestStaticAssets` dekt de routes, en een screenshot op 375px toont de link klein onder de melding.

## 2. Integratie

- [x] 2.1 Rebuild malandro (dat doet de gebruiker zelf). Controle: buiten 23:00–09:00 werkt insturen gewoon. Tussen 23:00 en 09:00 toont een inzending de nachtmelding.

## Workflow follow-up

- Voeg bij het archiveren de delta samen met `openspec/specs/filedrop/spec.md`.
