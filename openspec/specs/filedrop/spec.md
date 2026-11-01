# filedrop Specification

## Purpose
Een publiek formulier op `eghupload.toorren.net` waarmee buitenstaanders bestanden en videolinks
naar het EGH Scherm Team sturen. Inzendingen landen in een Nextcloud File Drop-share zonder dat
de inzender bestanden van anderen kan zien of de share-link leert kennen.

## Requirements

### Requirement: Inzending vereist naam, e-mail en geslaagde captcha
Het systeem SHALL een inzending alleen opslaan als er een niet-lege naam (max. 100 tekens), een
geldig e-mailadres en een door de Cap-server bevestigd captcha-token zijn meegestuurd. Deze
controles MUST plaatsvinden voordat er iets in Nextcloud wordt opgeslagen.

#### Scenario: Geldige inzending
- **WHEN** een inzending een naam, een geldig e-mailadres, een geldig captcha-token en minstens één bestand of link bevat
- **THEN** slaat het systeem de inzending op en antwoordt met een bevestiging

#### Scenario: Naam ontbreekt
- **WHEN** het veld naam leeg is
- **THEN** weigert het systeem de inzending met de melding "Vul je naam in." en slaat niets op

#### Scenario: Ongeldig e-mailadres
- **WHEN** het e-mailadres geen geldig adres is
- **THEN** weigert het systeem de inzending met de melding "Vul een geldig e-mailadres in."

#### Scenario: Captcha mislukt
- **WHEN** het captcha-token ontbreekt of door de Cap-server wordt afgewezen
- **THEN** weigert het systeem de inzending en slaat niets op

### Requirement: Honeypot negeert bots stil
Het systeem SHALL een inzending met een ingevuld verborgen veld `website` beantwoorden als
geslaagd, zonder iets op te slaan of te melden.

#### Scenario: Honeypot ingevuld
- **WHEN** het veld `website` niet leeg is
- **THEN** antwoordt het systeem met "Bedankt!" en slaat geen bestanden of links op

### Requirement: Inzending bevat minstens één bestand of link
Het systeem SHALL een inzending weigeren die geen bestand en geen geldige link bevat.

#### Scenario: Leeg formulier
- **WHEN** een inzending geen bestanden en geen links bevat
- **THEN** weigert het systeem de inzending met de melding dat er minstens één bestand of link nodig is

#### Scenario: Alleen links
- **WHEN** een inzending één of meer geldige links en geen bestanden bevat
- **THEN** slaat het systeem de inzending op

### Requirement: Maximale grootte per inzending
Het systeem SHALL een inzending groter dan 25 MB weigeren met een melding die het contactadres
eghmedia@evangelischegemeente.org noemt. Het formulier MUST deze grens en het
contactadres ook vooraf tonen.

#### Scenario: Te groot
- **WHEN** de bestanden samen groter zijn dan 25 MB
- **THEN** weigert het systeem de inzending met een melding die het contactadres noemt

#### Scenario: Grens zichtbaar
- **WHEN** iemand de pagina opent
- **THEN** staat bij het bestandsveld "Maximaal 25 MB" met een mailto-link naar het contactadres

### Requirement: Quota tegen misbruik
Het systeem SHALL per IP-adres maximaal 3 inzendingen per uur en 10 per 24 uur toestaan, en in
totaal maximaal 40 inzendingen en 1 GB per 24 uur. Alleen inzendingen met een geslaagde captcha
MUST meetellen. De tellers MUST een herstart van de dienst overleven.

#### Scenario: Limiet per IP bereikt
- **WHEN** een IP-adres in het afgelopen uur al 3 inzendingen deed
- **THEN** weigert het systeem een volgende inzending met de melding dat het maximum is bereikt

#### Scenario: Mislukte captcha telt niet mee
- **WHEN** een inzending op de captcha wordt geweigerd
- **THEN** verbruikt die inzending geen quotum

#### Scenario: Daglimiet bereikt
- **WHEN** in de afgelopen 24 uur 40 inzendingen of 1 GB zijn ontvangen
- **THEN** weigert het systeem nieuwe inzendingen en stuurt hooguit één Signal-alert per 24 uur

### Requirement: Opslag per maand en per inzending
Het systeem SHALL elke inzending opslaan in de map `<JJJJ-MM>/<JJJJMMDD-UUMMSS>/` in de
share, met tijd in Europe/Amsterdam. Naam en e-mail MUST NOT in map- of bestandsnamen staan.

#### Scenario: Eerste inzending van de maand
- **WHEN** op 30 oktober 2026 om 14:32:10 een inzending binnenkomt en de map `2026-10` nog niet bestaat
- **THEN** maakt het systeem `2026-10/20261030-143210/` aan en slaat daarin de inzending op

#### Scenario: Twee inzendingen in dezelfde seconde
- **WHEN** de map `20261030-143210` al bestaat
- **THEN** gebruikt het systeem `20261030-143210-2` voor de tweede inzending

### Requirement: Afzendergegevens in de inzendmap
Het systeem SHALL in elke inzendmap een bestand `_afzender.txt` opslaan met de naam, het
e-mailadres en het tijdstip van de inzending.

#### Scenario: Afzenderbestand aanwezig
- **WHEN** een inzending is opgeslagen
- **THEN** bevat de inzendmap `_afzender.txt` met naam, e-mailadres en tijdstip

### Requirement: Bestandsnamen blijven uniek binnen een inzending
Het systeem SHALL tekens die Nextcloud of sync-clients weigeren uit bestandsnamen verwijderen.
Komt een naam twee keer voor in één inzending, dan MUST de latere een volgnummer krijgen in
plaats van dat de inzending faalt.

#### Scenario: Dubbele bestandsnaam
- **WHEN** een inzending twee bestanden met de naam `foto.jpg` bevat
- **THEN** slaat het systeem ze op als `foto.jpg` en `foto (2).jpg`

### Requirement: Alleen videolinks van toegestane platforms
Het systeem SHALL maximaal 5 links per inzending accepteren, elk met een optionele titel. Een
link MUST https gebruiken en een host hebben van YouTube (`youtube.com`, `youtu.be`), Facebook
(`facebook.com`, `fb.watch`), Instagram (`instagram.com`) of Vimeo (`vimeo.com`), inclusief
subdomeinen zoals `www.` en `m.`. Het pad wordt niet gecontroleerd.

#### Scenario: Toegestane link
- **WHEN** een link `https://www.instagram.com/reels/DfG9eQtuo5k` wordt ingestuurd
- **THEN** accepteert het systeem de link

#### Scenario: Niet-toegestane host
- **WHEN** een link naar een ander domein wijst, of http in plaats van https gebruikt
- **THEN** weigert het systeem de inzending met een melding welke platforms zijn toegestaan

#### Scenario: Te veel links
- **WHEN** een inzending meer dan 5 links bevat
- **THEN** weigert het systeem de inzending

### Requirement: Links in video-links.txt
Het systeem SHALL de links van een inzending opslaan in `video-links.txt` in de inzendmap, in
UTF-8 met CRLF-regeleinden. Per link MUST er drie regels zijn: volgnummer, titel en de link
precies zoals ingestuurd, met een lege regel tussen de items.

#### Scenario: Bestandsindeling
- **WHEN** een inzending twee links bevat
- **THEN** bevat `video-links.txt` het blok `1`, titel, link, een lege regel, en het blok `2`, titel, link

#### Scenario: Link blijft ongewijzigd
- **WHEN** de link `https://vimeo.com/1132937?fl=pl&fe=cm` wordt ingestuurd
- **THEN** staat precies die tekenreeks, met parameters, in `video-links.txt`

### Requirement: Titel per link
Het systeem SHALL als titel de door de inzender ingevulde titel gebruiken. Is die leeg, dan MUST
het voor YouTube en Vimeo de titel en auteur via de officiële oEmbed ophalen, als `Titel
(Auteur)`. Lukt dat niet, of gaat het om Facebook of Instagram, dan MUST de platformnaam de
titel zijn. Het ophalen van een titel MUST de inzending nooit laten falen.

#### Scenario: Ingevulde titel
- **WHEN** de inzender bij een link de titel "Voor zondag, vanaf 2:15" invult
- **THEN** staat "Voor zondag, vanaf 2:15" als titel in `video-links.txt`

#### Scenario: YouTube zonder ingevulde titel
- **WHEN** de link `https://www.youtube.com/watch?v=MTn_bhTVr2U` zonder titel wordt ingestuurd
- **THEN** is de titel "Ren - Vincent's Tale - Starry Night (Ren)"

#### Scenario: Instagram zonder ingevulde titel
- **WHEN** een Instagram-link zonder titel wordt ingestuurd
- **THEN** is de titel "Instagram-reel" en roept het systeem geen Meta-dienst aan

#### Scenario: oEmbed niet bereikbaar
- **WHEN** de oEmbed-aanroep faalt of te lang duurt
- **THEN** is de titel de platformnaam, bijvoorbeeld "YouTube-video", en wordt de inzending toch opgeslagen

### Requirement: Optioneel bericht als tekstbestand
Het systeem SHALL een optioneel bericht van maximaal 1000 tekens accepteren en dat opslaan als
`bericht.txt` (UTF-8, CRLF) in de inzendmap, alleen als het niet leeg is. Het bericht MUST NOT
in de Signal-melding staan. Een bericht alleen, zonder bestand of link, MUST geweigerd worden.

#### Scenario: Inzending met bericht
- **WHEN** een inzending een link en het bericht "Graag zondag tijdens de mededelingen" bevat
- **THEN** staat dat bericht in `bericht.txt` in de inzendmap en niet in de Signal-melding

#### Scenario: Geen bericht
- **WHEN** het berichtvak leeg is
- **THEN** maakt het systeem geen `bericht.txt` aan

#### Scenario: Bericht te lang
- **WHEN** het bericht langer is dan 1000 tekens
- **THEN** weigert het systeem de inzending met een melding over de maximale lengte

#### Scenario: Alleen een bericht
- **WHEN** een inzending alleen een bericht bevat, zonder bestand of link
- **THEN** weigert het systeem de inzending met de melding dat er minstens één bestand of link nodig is

### Requirement: Melding per inzending via Signal
Het systeem SHALL na elke opgeslagen inzending een Signal-melding sturen met naam, e-mailadres,
de mapnaam, de bestanden en de links. Een falende Signal-dienst MUST de inzending niet laten
mislukken.

#### Scenario: Melding met links
- **WHEN** een inzending met één link en geen bestanden is opgeslagen
- **THEN** noemt de Signal-melding de afzender, de mapnaam en de link

#### Scenario: Signal onbereikbaar
- **WHEN** de Signal-dienst niet antwoordt
- **THEN** krijgt de inzender toch een bevestiging en blijft de inzending opgeslagen

### Requirement: Share-link blijft geheim
Het systeem MUST NOT de Nextcloud-share-link of het share-token tonen aan inzenders, in de
pagina, in antwoorden of in de publieke repository.

#### Scenario: Pagina en antwoorden
- **WHEN** iemand de pagina opent of een inzending doet
- **THEN** bevat geen enkel antwoord het share-token

### Requirement: Melding als de opslag onbereikbaar is
Als de opslag niet bereikbaar is, SHALL het systeem de inzending weigeren met HTTP 503. De melding
noemt de vaste nachtpauze van 23:00 tot 09:00 en zegt dat de inzender het daarna opnieuw kan
proberen. Of de opslag onbereikbaar is, MUST het systeem afleiden uit het antwoord van de opslag
(een verbindingsfout of HTTP 502, 503 of 504). Het tijdstip mag daarvoor niet gebruikt worden.

#### Scenario: Insturen tijdens de nachtpauze
- **WHEN** iemand iets instuurt en de opslag antwoordt met HTTP 503
- **THEN** krijgt de inzender HTTP 503 met een melding die 23:00 en 09:00 noemt

#### Scenario: Opslag valt weg tijdens het insturen
- **WHEN** de opslag tijdens het versturen van een bestand onbereikbaar wordt
- **THEN** krijgt de inzender dezelfde melding over de onbereikbare opslag

#### Scenario: Overdag onbereikbaar
- **WHEN** de opslag overdag onbereikbaar is
- **THEN** krijgt de inzender dezelfde melding, omdat de klok niet meetelt

### Requirement: Contactadres bij een opslagfout
Elke melding over een mislukte opslag SHALL eindigen met de zin dat de inzender contact kan opnemen
via het contactadres als het opnieuw gebeurt. Dat geldt zowel voor een onbereikbare opslag als
voor een andere opslagfout. Op de pagina MUST daarachter een kleinere link "klik hier" staan, die
een mail aan het contactadres opent.

#### Scenario: Andere opslagfout
- **WHEN** de opslag een onverwachte fout geeft, zoals HTTP 500
- **THEN** noemt de melding dat het opslaan mislukte en het contactadres

#### Scenario: Onbereikbare opslag
- **WHEN** de opslag onbereikbaar is
- **THEN** noemt de melding ook het contactadres

#### Scenario: Maillink in de melding
- **WHEN** de pagina een foutmelding toont waarin het contactadres staat
- **THEN** staat daarachter in kleinere letters "klik hier", als link die een mail aan het contactadres opent

### Requirement: Huisstijl-middelen komen van de eigen dienst
De pagina SHALL haar lettertypes, achtergrond en logo alleen van de eigen dienst laden. Ze MUST
geen verzoek doen naar een font-dienst, CDN of de kerk-website. De enige externe bron blijft de
robotcontrole.

#### Scenario: Geen externe huisstijlbronnen
- **WHEN** iemand de pagina opent
- **THEN** komen alle lettertype-, afbeelding- en stijlverzoeken van eghupload.toorren.net

### Requirement: Hero toont de EGH-achtergrond
De kop van de pagina, met logo, kerknaam en titel, SHALL de EGH-achtergrond "Dusk To Dawn 1b"
tonen. Het formulier daaronder MUST een witte achtergrond houden. Als de afbeelding niet laadt,
MUST de kop het kleurverloop in dezelfde tinten tonen.

#### Scenario: Achtergrond geladen
- **WHEN** iemand de pagina opent
- **THEN** staat de afbeelding achter de kop en is het formulier wit

#### Scenario: Afbeelding laadt niet
- **WHEN** de afbeelding niet geladen kan worden
- **THEN** toont de kop het kleurverloop en blijven logo en titel leesbaar

### Requirement: Script-lettertype voor de titel
De grote titel in de kop SHALL in Blenda Script staan. Dit lettertype MUST altijd door de dienst
geleverd worden, zonder handmatige stap op de server.

#### Scenario: Titel in script
- **WHEN** iemand de pagina opent
- **THEN** staat de grote titel in Blenda Script

### Requirement: Gelicentieerd lettertype is optioneel
Alle tekst behalve de titel SHALL in Letter Gothic Std staan als het fontbestand op de server
aanwezig is, zoals in de EGH-presentaties. Ontbreekt het, dan MUST de pagina dezelfde tekst in
Roboto tonen en volledig werken. Het fontbestand MUST NOT in de publieke repository
staan.

#### Scenario: Fontbestand aanwezig
- **WHEN** het Letter Gothic-bestand op de server staat en iemand de pagina opent
- **THEN** staan kerknaam, koppen, uitleg, labels, velden en meldingen in Letter Gothic Std

#### Scenario: Fontbestand ontbreekt
- **WHEN** het Letter Gothic-bestand niet op de server staat
- **THEN** antwoordt de dienst op het fontverzoek met "niet gevonden", toont de pagina die teksten in Roboto en kan iemand gewoon insturen

### Requirement: Terugvallettertype komt van de dienst
Het terugvallettertype Roboto SHALL door de dienst zelf geleverd worden, zodat de pagina ook op
apparaten zonder Roboto (iPhone, Mac, Windows) niet in het standaardlettertype van de browser
staat. Het script-lettertype MUST NOT voor andere tekst dan de titel gebruikt worden.

#### Scenario: Apparaat zonder Roboto en zonder Letter Gothic op de server
- **WHEN** het Letter Gothic-bestand ontbreekt en het apparaat heeft geen Roboto
- **THEN** staat de tekst in Roboto, geleverd door eghupload.toorren.net
