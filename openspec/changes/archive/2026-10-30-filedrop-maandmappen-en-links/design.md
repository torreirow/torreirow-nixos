# Design

## Context

`filedrop` is een Go-dienst (`pkgs/filedrop`) achter nginx op `upload.toorren.net`. Hij leest
het multipart-formulier als stroom, op volgorde. Eerst de tekstvelden (naam, e-mail,
`cap-token`, honeypot), daarna de bestanden. Bij het eerste bestand valideert hij alles,
reserveert hij een quotumslot en maakt hij met MKCOL een map aan. Daarna streamt hij elk bestand
met een chunked PUT naar de publieke WebDAV van de File Drop-share
(`/public.php/dav/files/<token>/`). De share heeft alleen aanmaakrechten (permissions 4). Lezen
(PROPFIND), overschrijven en verwijderen kunnen dus niet. Zie proposal.md voor de aanleiding en
`specs/filedrop/spec.md` voor het gedrag.

## Goals / Non-Goals

**Goals:**
- De nieuwe mappenstructuur en het linkverwerken passen in de bestaande stroomverwerking, zonder
  bestanden op malandro te bufferen.
- Een inzending met alleen links gebruikt dezelfde validatie, quota en melding als een upload.

**Non-Goals:**
- Video's zelf downloaden (bijvoorbeeld met yt-dlp). De lezer van `video-links.txt` downloadt
  zelf.
- Titels van Facebook of Instagram ophalen. Daarvoor is een Meta-app-token nodig, of de pagina
  zou geschraapt moeten worden terwijl we ons voordoen als crawler. Dat doen we bewust niet.
- Oude inzendmappen verhuizen naar de nieuwe indeling.
- Een bevestigingsmail aan de inzender.

## Decisions

### 1. Veldvolgorde: links staan vóór de bestanden in het formulier
De linkvelden (`link1..5`, `titel1..5`) komen in de DOM vóór het bestandsveld, net als naam,
e-mail en `cap-token`. Bij het eerste bestandsdeel zijn dus alle tekstvelden bekend. Dan valideert
de dienst ook de links. Een ongeldige link weigert de hele inzending voordat er één byte naar
Nextcloud gaat. Bevat de inzending geen bestanden, dan gebeurt dezelfde validatie aan het einde
van de stroom.
*Alternatief:* links in een apart verzoek naar een eigen endpoint. Afgewezen: dat geeft twee
captcha-tokens, twee quotumslots en twee mappen voor wat voor de inzender één inzending is.

### 2. Map pas aanmaken als er iets op te slaan is
De dienst maakt de inzendmap lui aan, bij het eerste bestand of bij het wegschrijven van
`video-links.txt`. Eerst de maandmap met MKCOL: 201 (nieuw) en 405 (bestaat al) zijn allebei
goed. Daarna de inzendmap `JJJJMMDD-UUMMSS`, bij 405 met de achtervoegsels `-2`, `-3` enzovoort
(maximaal 20 pogingen). Omdat PROPFIND niet mag, is "MKCOL en kijken naar de 405" de enige manier
om te weten of een map al bestaat.

### 3. `_afzender.txt` en `video-links.txt` als laatste schrijven
Beide bestanden worden aan het einde van de stroom geschreven met een gewone PUT met bekende
lengte. Zo kan `_afzender.txt` ook de definitieve bestandenlijst bevatten. Mislukt het
wegschrijven van een van die twee, dan geldt de inzending als mislukt, met dezelfde foutroute
als een mislukte bestandsupload (melding aan de inzender en een Signal-melding over de
afgebroken upload).

### 4. Unieke bestandsnamen bijhouden in het geheugen
Overschrijven mag niet en een bestaand bestand kan niet worden opgevraagd. Daarom houdt de dienst
per inzending een set met de namen die al gebruikt zijn. Bij een dubbele naam wordt het
`naam (2).ext`, `naam (3).ext`. De gereserveerde namen `_afzender.txt` en `video-links.txt`
zitten vanaf het begin in de set, zodat een geüpload bestand met zo'n naam ook een volgnummer
krijgt.

### 5. Allowlist op host, niet op pad
De dienst parset de link als URL. Hij eist `https`, en een host die gelijk is aan een van
`youtube.com`, `youtu.be`, `facebook.com`, `fb.watch`, `instagram.com`, `vimeo.com`, of daarop
eindigt met een `.` ervoor (dus `www.` en `m.`, maar niet `evilyoutube.com`). Paden verschillen
per platform en veranderen (`/reel/` en `/reels/`, `/shorts/`, `/watch?v=`). Controleren op pad
zou geldige links weigeren zonder iets veiliger te maken. Daarnaast geldt een maximale lengte
per link (2048 tekens) en per titel (200 tekens). Lege linkvelden worden overgeslagen.

### 6. oEmbed alleen voor YouTube en Vimeo, parallel en met time-out
Voor links zonder ingevulde titel roept de dienst de officiële endpoints aan
(`https://www.youtube.com/oembed?format=json&url=…`, `https://vimeo.com/api/oembed.json?url=…`).
Dat gebeurt parallel per link, met een time-out van 5 seconden per aanroep, en pas nadat de
captcha en de quota zijn gecontroleerd. Een bot kan de dienst dus niet als proxy gebruiken. Uit
het antwoord gebruiken we alleen `title` en `author_name`. Controletekens worden eruit gehaald en
alles wordt afgekapt op 200 tekens. Bij een fout, een time-out of een leeg antwoord valt de titel
terug op de platformnaam.
In de verkenning (30-10-2026) gaf oEmbed een titel voor YouTube (gewone video en Shorts) en voor
Vimeo, ook met `?fl=pl&fe=cm`. Facebook gaf zonder token geen titel, Instagram gaf een fout.

### 7. Titels en links zijn tekst van de inzender
De inhoud van `video-links.txt` en `_afzender.txt` is gewone tekst die niemand uitvoert. Er
gelden wel regels: geen controletekens en geen regeleinden binnen een titel, zodat een titel de
indeling met drie regels per item niet kan breken. Regeleinden zijn CRLF.

## Risks / Trade-offs

- [oEmbed-endpoint verandert of throttlet] → de titel valt terug op de platformnaam. De
  inzending zelf hangt er nooit van af.
- [Een link-inzending is goedkoper dan een upload en dus aantrekkelijker voor spam] → dezelfde
  captcha en quota (3/uur, 10/dag per IP, 40/dag totaal). Een spammer kan alleen links naar vier
  platforms achterlaten, en die belanden in een map die niet publiek leesbaar is.
- [Twee inzendingen in dezelfde seconde] → het achtervoegsel `-2` uit Decision 2.
- [Halve inzending na een fout tijdens het streamen] → hetzelfde als nu: de map blijft met de al
  opgeslagen bestanden staan, de inzender krijgt een foutmelding en er gaat een Signal-melding
  uit. Opruimen gebeurt met de hand in Nextcloud.
- [De indeling verandert terwijl er al oude mappen staan] → de oude mappen blijven naast de
  nieuwe maandmappen staan. De team-instructie is "nieuwe inzendingen staan in de maandmap".

## Migration Plan

1. Bouwen en lokaal testen met nep-diensten (Cap, WebDAV en Signal op localhost).
2. `nixos-rebuild switch` op malandro, daarna één echte inzending via de browser met een bestand
   en een YouTube-link. Controleren: de mappenstructuur, `_afzender.txt`, `video-links.txt` en
   de Signal-melding.
3. Met de hand in Nextcloud (`nxceghmedia`): de oude test- en naammappen verwijderen, en de share
   opnieuw aanmaken en het token bijwerken met `ragenx -e filedrop-env.age`.

Terugdraaien: de vorige generatie activeren (`nixos-rebuild switch --rollback`) of de commit
terugdraaien. De opgeslagen gegevens hoeven niet te worden omgezet.
