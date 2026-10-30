# Tasks

## 1. Mappenstructuur en unieke namen

- [x] 1.1 Map per inzending vervangen door `<JJJJ-MM>/<JJJJMMDD-UUMMSS>/` (maandmap via MKCOL, 201/405 allebei ok; inzendmap met `-2`, `-3` bij 405); verify: Go-unittest met een WebDAV-nep die 405 geeft op de eerste naam levert `20261030-143210-2`
- [x] 1.2 Unieke bestandsnamen per inzending (`foto (2).jpg`), met `_afzender.txt` en `video-links.txt` vanaf het begin gereserveerd; verify: unittest met twee keer `foto.jpg` en één keer `_afzender.txt` als upload
- [x] 1.3 `_afzender.txt` (naam, e-mail, tijdstip, bestandenlijst; UTF-8, CRLF) aan het einde van de inzending wegschrijven; verify: lokale test met nep-diensten toont de juiste inhoud in de PUT-body
- [x] 1.4 `docs/filedrop.md`: opslagindeling en `_afzender.txt` bijwerken; verify: de rij "Opslag" en een voorbeeldboom kloppen met 1.1–1.3

## 2. Videolinks

- [x] 2.1 Formulier: blok met 5 paren `linkN`/`titelN` vóór het bestandsveld; bestandsveld niet meer `required`; client-side check "minstens één link of bestand"; verify: pagina lokaal openen en de veldvolgorde in de FormData controleren
- [x] 2.2 Server: links valideren volgens de allowlist op host (https, host gelijk aan of eindigend op `.`+domein, max 2048 tekens per link, max 200 per titel, max 5); verify: tabelgestuurde unittest met de testlinks uit de verkenning plus `http://`, `evilyoutube.com` en `youtube.com.evil.nl`
- [x] 2.3 Inzending zonder bestanden maar met links ondersteunen (validatie aan het einde van de stroom); "minstens één bestand of link" afdwingen; verify: lokale test met alleen een link geeft 200, een leeg formulier geeft de juiste fout
- [x] 2.4 oEmbed voor YouTube en Vimeo (parallel, time-out 5 s, `Titel (Auteur)`, controletekens eruit, max 200), met terugval op de platformnaam; verify: unittest met een nep-oEmbed (ok / time-out / leeg) en één handmatige run tegen de echte endpoints met de YouTube- en Vimeo-testlinks
- [x] 2.5 `video-links.txt` schrijven (nummer / titel / link, lege regel ertussen, UTF-8, CRLF, link exact zoals ingestuurd); verify: unittest vergelijkt de bytes met het verwachte voorbeeld uit de spec
- [x] 2.6 Signal-melding uitbreiden met de links en de nieuwe mapnaam; verify: de body naar de nep-Signal bevat de mapnaam en de links
- [x] 2.7 `docs/filedrop.md`: sectie "Videolinks" (allowlist, titelbron, voorbeeld van `video-links.txt`, waarom geen Meta); verify: het voorbeeld in de docs is gelijk aan de unittest-verwachting uit 2.5
- [x] 2.8 Pagina-indeling: genummerde secties (1 Jouw gegevens, 2 Bestanden, "en/of", 3 Videolinks, 4 Versturen) met kopje en scheidingslijn; captcha net boven de knop; grote knop "Bestanden kiezen"; tekstvelden blijven vóór de bestanden verstuurd; verify: unittest controleert de volgorde van de secties en de captcha in de geserveerde pagina, en de FormData-volgorde blijft gelijk (bestaande tests slagen)
- [x] 2.9 Uitleg in gewone taal: uitklapblok "Handleiding: hoe werkt het insturen?" (standaard dicht, stappen, link kopiëren, groter dan 25 MB), privacyzin onder sectie 1, eenvoudige hints per sectie, bevestiging "Bedankt! … Het Scherm Team bekijkt je inzending." en foutmeldingen zonder technische termen; verify: unittests op de bevestiging en de linkfoutmelding, en de pagina bevat een `<details>` zonder `open`
- [x] 2.10 `docs/filedrop.md`: korte sectie "Pagina" (secties, handleiding, waar de teksten staan); verify: de beschrijving klopt met de geserveerde pagina
- [x] 2.11 Meldingen als popup (`<dialog>`): gelukt (groen, "Sluiten", formulier leeg) en niet gelukt (rood, "Terug naar het formulier", invoer blijft staan); "Bezig met versturen…" en de voortgangsbalk blijven onder de knop; verify: `TestPageLayout` vindt de dialog, en lokaal (2.12) tonen een geslaagde en een mislukte inzending de juiste popup
- [x] 2.12 Lokaal testen: `pkgs/filedrop/dev.sh` start de dienst op 127.0.0.1:18111 met nep-WebDAV (schrijft naar `dev-share/`), nep-Signal (terminal) en een robotcontrole die altijd slaagt; `FILEDROP_DEV_HTML` laat de dienst `index.html` bij elke paginaweergave opnieuw lezen; verify: script starten, een inzending doen en de bestanden in `dev-share/` zien; een tekstwijziging is na F5 zichtbaar
- [x] 2.13 Berichtvak: sectie 4 "Bericht (mag je leeg laten)" vóór Versturen (wordt 5), max 1000 tekens met teller; server weigert langer, slaat het niet-lege bericht op als `bericht.txt` (gereserveerde naam, CRLF) en laat het buiten de Signal-melding; verify: unittests voor opslag, geen bestand bij leeg bericht, te lang, alleen-bericht, en dat de Signal-body het bericht niet bevat; `TestPageLayout` kent de nieuwe sectie
- [x] 2.14 `docs/filedrop.md` bijwerken (sectie 4, `bericht.txt` in de boom) en lokaal met `dev.sh` controleren; verify: inzending met bericht geeft `dev-share/…/bericht.txt` en de terminal-Signal toont het bericht niet

## 3. Uitrol en controle

- [x] 3.1 `go vet` en `go test` slagen en `nixos-rebuild switch --flake .#malandro` slaagt; verify: `systemctl is-active filedrop` geeft active en `systemctl --failed` is leeg
- [x] 3.2 End-to-end via de browser: één inzending met een bestand en een YouTube-link, en één met alleen een Instagram-link; verify: in Nextcloud staan `2026-MM/…/` met `_afzender.txt`, `video-links.txt` (titel via oEmbed resp. "Instagram-reel") en het bestand, en er kwamen twee Signal-meldingen

## Workflow follow-up

- Met de hand in Nextcloud (`nxceghmedia`): de oude test- en naammappen verwijderen, de share opnieuw aanmaken en `NEXTCLOUD_SHARE_TOKEN` bijwerken met `ragenx -e filedrop-env.age`.
- De change archiveren na de review (`/opsx:archive`), waarna `openspec/specs/filedrop/spec.md` ontstaat.
