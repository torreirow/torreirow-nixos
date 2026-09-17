## Context

Gemeten op lobos, 2026-09-16/17. De relevante feiten die het ontwerp sturen:

```
22:24:55  ▼ lobos suspend (s2idle)
          │   23:00  bobadela1 uit — lobos slaapt, geen timer, geen sync, geen melding
06:24:37  ▲ lobos suspend exit
06:24:37  ✗ sync faalt → Signal   "Host nxc.toorren.net not found"   (lobos zonder netwerk)
06:34:20  ✗ sync faalt → Signal   "502 Bad Gateway"                  (nginx leeft, Nextcloud niet)
06:42:44  ✓ sync geslaagd                                            (server was gewekt)
```

Vier constateringen hieruit:

1. **De nacht is geen probleem.** Een `systemd.user.timer` staat stil in suspend. Het ruisvenster
   is de ~18 minuten tussen wakker worden en de server wekken, niet de negen uur downtime.
2. **"Server bereikbaar" is niet triviaal te meten.** Er staat een nginx voor die altijd antwoordt:
   de server uit geeft **502**, geen connection-refused. Een poort- of ping-probe zegt dus ten
   onrechte "beschikbaar". Alleen `status.php` met HTTP 200 én `installed:true` en
   `maintenance:false` is een betrouwbaar signaal.
3. **Mislukkingen hebben verschillende oorzaken die er niet toe doen.** DNS-fout, 502, of de
   HTTP 429 van 2026-09-16 (brute-force-throttling) — voor de vraag "is er nog gesynct?" is het
   onderscheid irrelevant.
4. **`network-online.target` bestaat niet in de user-manager** (`LoadState=not-found`). De
   `After`/`Wants` in de unit zijn decoratie; vandaar dat de sync op dezelfde seconde als de
   resume vuurde.

Bestaande bouwstenen: `notify-signal@.service` (meldkanaal via Home Assistant), en het
probe-patroon uit `remarkable-sync` als precedent voor "afwezigheid is geen fout".

## Goals / Non-Goals

**Goals:**

- Geen melding meer bij geplande onbereikbaarheid van de Nextcloud-server.
- Wel een melding wanneer er werkelijk te lang niet gesynct is, ook als de oorzaak onbekend is.
- Herbruikbaar voor ander periodiek werk, zonder dat het beleid van het ene item het andere raakt.
- Eén meldkanaal en één plek voor het token houden.

**Non-Goals:**

- Automatisch wekken van bobadela1 (wake-on-LAN) — de gebruiker regelt dat zelf.
- Een echte dodemansknop die ook het uitvallen van lobos zelf detecteert; dat vereist een
  heartbeat naar een altijd-draaiende host.
- Staleness-bewaking op `remarkable-sync`.
- Snellere detectie dan één keer per dag.

## Decisions

### Beslissing 1 — Meet het resultaat, niet de storing

De voor de hand liggende oplossing was een readiness-probe vóór elke sync, zodat mislukkingen bij
een slapende server geen melding opleveren. Dat vereist het onderscheiden van oorzaken (geen
netwerk / server uit / echt stuk), en daarmee kennis van HTTP-statussen, `maintenance`-vlaggen en
de nginx-ervoor.

Een staleness-check omzeilt dat volledig: de vraag "is er in de afgelopen 24 uur één keer gesynct?"
is te beantwoorden zonder ook maar één oorzaak te kennen. De server die 's ochtends een uur uit
staat is dan simpelweg geen gebeurtenis, want later op de dag lukt het wel.

Dit is dus een laag mínder machinerie dan het alternatief, niet meer.

### Beslissing 2 — Twee drempels, met readiness als verfijning

De kale variant (">24u → melden") heeft één zwakte: kom je maandagochtend terug van een weekend
weg, dan meldt hij terecht maar overbodig dat er drie dagen niet gesynct is — precies terwijl je de
server al aan het wekken bent.

De omgekeerde variant ("alleen melden als de server bereikbaar is") lost dat op maar introduceert
een ergere blinde vlek: vergeet je de server een paar dagen te wekken, dan is hij op geen enkel
controlemoment bereikbaar en hoor je dus nooit iets — juist het geval waarin een herinnering nuttig
was.

Gekozen: **beide**, als twee drempels per item.

```
  leeftijd van het laatste succes
  ──────────────────────────────────────────────────────────────►
   0                  softMaxAge (24u)          hardMaxAge (48u)
   │                       │                          │
   │   geen melding        │   melden ALS readiness   │   altijd melden
   │                       │   slaagt                 │
```

Zonder `readinessCommand` vallen beide drempels samen en is het gedrag de kale variant. Het
readiness-commando is daarmee een eigenschap van het bewaakte item, niet iets Nextcloud-specifieks
in de module — dat houdt de module generiek.

### Beslissing 3 — `ExecStartPost=` als bron van waarheid

Er is vandaag geen enkele plek waar "laatst geslaagd" staat:

| Bron | Waarom niet |
|------------------|--------------------------------------------------------|
| systemd | kent alleen de uitkomst van de láátste run |
| journald | gaat hier terug tot 31 aug, maar log-scrapen voor state is broos |
| nextcloud-sync | houdt geen state bij |

`ExecStartPost=` draait per definitie alleen wanneer `ExecStart` is geslaagd. Eén `touch` van een
stempelbestand volstaat, zonder een regel aan het sync-commando te veranderen. De mtime ís de
state; er hoeft niets geparseerd te worden.

Pad: `~/.local/state/nextcloud-sync/last-success-<naam>`, voorspelbaar afgeleid van de sync-naam.

### Beslissing 4 — De teller begint bij installatie

Een ontbrekend stempelbestand is dubbelzinnig: "nog nooit geslaagd" of "net geïnstalleerd". Beide
uitleggen leiden tot slecht gedrag — meteen alarm bij een verse installatie, of eeuwig zwijgen bij
een sync die nooit werkt.

Daarom maakt de module het stempelbestand aan bij activatie als het nog niet bestaat. De betekenis
wordt daarmee eenduidig: *"zo lang geleden is het voor het laatst gelukt, of anders zo lang geleden
is de bewaking ingesteld"*. Een verse installatie die nooit synct meldt zich dus na `hardMaxAge`,
en dat is precies goed.

### Beslissing 5 — Dagelijks, met `Persistent=true`

`OnCalendar` één keer per dag plus `Persistent=true`, zodat een gemist moment wordt ingehaald zodra
lobos wakker is. Zonder dat vlaggetje slaat een slapende laptop controles gewoon over.

De inhaalslag landt in de praktijk vaak 's ochtends, precies in het gat waarin de server nog uit
is. Dat is geen probleem: beslissing 2 zorgt dat er in het zachte venster dan niets gemeld wordt.
Het controlemoment en de variantkeuze hangen dus samen — met alleen de kale variant zou het
tijdstip veel kritischer zijn.

### Beslissing 6 — Per-mislukking-melding blijft op `remarkable-sync`

Die module heeft al een probe waardoor een afwezig apparaat exit 0 oplevert. Een faalmelding
betekent daar dus altijd iets echts (SSH stuk, webinterface uit, download mislukt), en snelle
detectie is daar gratis.

Omgekeerd zou een staleness-alarm op `remarkable-sync` pure ruis zijn: de tablet hangt er legitiem
dagen niet aan. Het patroon generaliseert, het beleid niet — daarom is bewaking opt-in per item.

### Beslissing 7 — De verzender wordt losgetrokken van de faalmelding

Bij het bouwen bleek `notify-signal` niet herbruikbaar: het script bouwt zélf de tekst
*"unit X gefaald"* plus de laatste journalregels, en leest zélf het token. Een staleness-melding is
geen unit-fout, maar mag volgens de spec ook geen eigen kanaal en eigen tokenlezing krijgen.

Overwogen en verworpen: de check laten falen en `OnFailure` gebruiken. Dan zou het bericht
"unit staleness-check@nextcloud gefaald" luiden met de echte tekst in de bijgevoegde journalregels.
Dat werkt zonder één regel wijziging, maar noemt een verstreken drempel een crash -- precies het
soort misleidende formulering waar deze changes zich tegen richten.

Gekozen: het verzendgedeelte (token lezen, jq, curl met `--fail-with-body`) wordt een los script,
naar buiten beschikbaar als `services.notify-signal.sendCommand`. De faalmelding bouwt zijn tekst
en roept diezelfde verzender aan. Eén kanaal, één tokenlocatie, twee soorten berichten.

### Beslissing 8 — Dode netwerk-afhankelijkheid opruimen

`After`/`Wants=network-online.target` in de sync-unit doen niets (`LoadState=not-found` in de
user-manager). Ze suggereren een wachtgedrag dat er niet is. Weghalen verandert niets aan het
draaiende systeem en voorkomt een verkeerde aanname bij de volgende diagnose. Zelfde klasse als
`--silent` en `curl -s` uit de vorige ronde: configuratie die eruitziet alsof ze iets doet.

## Risks / Trade-offs

- **Reactietijd van tien minuten naar een dag.** Bewust: het sync-volume is klein en de server is
  een deel van de dag sowieso uit. Wie sneller wil, zet `softMaxAge` lager — maar loopt dan weer
  tegen het ochtendgat aan, waarvoor de readiness-check bestaat.
- **Valt lobos zelf uit, dan zwijgt alles.** De monitor draait op dezelfde machine als het werk dat
  hij bewaakt. Dat is geen dodemansknop. Een heartbeat naar malandro zou dat dichten en is een
  logische volgende change, maar valt hier buiten scope.
- **Twee drempels zijn meer uit te leggen dan één.** De prijs voor het dichten van beide blinde
  vlekken. Beperkt door de default-waarden (24u/48u) en doordat weglaten van `readinessCommand`
  terugvalt op eenvoudig gedrag.
- **Het readiness-commando kan zelf liegen.** Een captive portal kan HTTP 200 met HTML teruggeven;
  daarom moet de check op inhoud toetsen (`installed:true`, `maintenance:false`), niet op de
  statuscode alleen.
- **`Persistent=true` kan een stapel gemiste momenten samenvoegen.** systemd voert er één uit, niet
  één per gemiste dag, dus dat levert geen meldingenregen op — te verifiëren bij de eerste
  meerdaagse afwezigheid.
