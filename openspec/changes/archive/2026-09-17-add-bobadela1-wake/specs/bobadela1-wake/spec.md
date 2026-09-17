## Purpose

Automatiseert het 's ochtends wekken van bobadela1 (die elke avond 23:00 uitgaat) vanaf de altijd-aan
host malandro, met doorzettende Wake-on-LAN-pogingen, een Nextcloud-gezondheidscheck als succescriterium,
en een onderscheidende Signal-melding wanneer het wekken of Nextcloud faalt.

## ADDED Requirements

### Requirement: Geautomatiseerde ochtend-wake op vast tijdstip

Het systeem SHALL bobadela1 elke dag om 09:00 automatisch proberen te wekken via een systemd-timer op
malandro. De timer SHALL dagelijks draaien inclusief weekend en SHALL een gemiste activering na een
malandro-herstart inhalen (`Persistent=true`).

#### Scenario: Reguliere ochtend-wake

- **WHEN** het 09:00 is en bobadela1 staat uit
- **THEN** start malandro de wake-service die bobadela1 probeert te wekken

#### Scenario: Gemiste activering wordt ingehaald

- **WHEN** malandro om 09:00 niet draaide en kort daarna opstart
- **THEN** haalt de timer de wake-activering alsnog in

#### Scenario: bobadela1 is al gezond

- **WHEN** de wake-service start terwijl bobadela1 al bereikbaar is en Nextcloud gezond antwoordt
- **THEN** eindigt de service succesvol zonder een magic packet te sturen

### Requirement: Doorzettende Wake-on-LAN met begrensd venster

Het systeem SHALL Wake-on-LAN magic packets naar bobadela1 sturen en gedurende maximaal 30 minuten blijven
proberen, waarbij het elke 5 minuten een nieuwe burst verstuurt en tussentijds de bereikbaarheid pollt.
Zodra het succescriterium is bereikt SHALL het proberen onmiddellijk stoppen.

#### Scenario: Host komt op na enkele bursts

- **WHEN** bobadela1 na een paar minuten en enkele WoL-bursts bereikbaar wordt
- **THEN** stopt het versturen van verdere bursts en gaat de service door naar de Nextcloud-check

#### Scenario: Venster verloopt zonder reactie

- **WHEN** bobadela1 binnen 30 minuten niet bereikbaar wordt
- **THEN** stopt de service met proberen en meldt het als mislukt

### Requirement: Nextcloud-gezondheid is het succescriterium

Het systeem SHALL de wake pas als geslaagd beschouwen wanneer Nextcloud op bobadela1 daadwerkelijk gezond
antwoordt, niet enkel wanneer de host op ICMP-ping reageert. Gezond SHALL betekenen: het
Nextcloud-statuseindpunt geeft HTTP 200 met een geïnstalleerde, niet-in-onderhoud staat.

#### Scenario: Host pingt en Nextcloud is gezond

- **WHEN** bobadela1 bereikbaar is en het Nextcloud-statuseindpunt HTTP 200 met `installed=true` en
  `maintenance=false` teruggeeft
- **THEN** eindigt de service succesvol

#### Scenario: Host pingt maar Nextcloud is nog niet gereed

- **WHEN** bobadela1 bereikbaar wordt maar Nextcloud binnen het venster niet gezond antwoordt
- **THEN** blijft de service pollen tot Nextcloud gezond is of het 30-minuten-venster verloopt

### Requirement: Onderscheidende faal-notificatie via Signal

Het systeem SHALL bij mislukking een Signal-melding sturen die onderscheid maakt tussen de faaloorzaken.
Wanneer bobadela1 niet bereikbaar werd SHALL de melding aangeven dat de host niet opkwam. Wanneer bobadela1
wél bereikbaar was maar Nextcloud niet gezond werd SHALL de melding dat expliciet aangeven. De melding
SHALL best-effort zijn: een falende Signal-API SHALL de service niet blokkeren.

#### Scenario: Host kwam niet op

- **WHEN** het 30-minuten-venster verloopt zonder dat bobadela1 ooit bereikbaar was
- **THEN** ontvangt de beheerder een Signal-melding dat bobadela1 niet opkwam na de WoL-pogingen

#### Scenario: Host op, Nextcloud niet gezond

- **WHEN** bobadela1 bereikbaar was maar Nextcloud binnen het venster niet gezond werd
- **THEN** ontvangt de beheerder een Signal-melding dat de host op is maar Nextcloud niet reageert

#### Scenario: Signal-API onbereikbaar

- **WHEN** het versturen van de Signal-melding faalt
- **THEN** verandert dat de uitkomst van de service niet en blokkeert het niets

### Requirement: Wake-logica uit één gedeelde bron

Het systeem SHALL de wake-logica uit één nix-beheerde bron leveren, bruikbaar door zowel de
root-systeemservice als handmatige uitvoering. De systeemservice SHALL een betrouwbaar store-pad gebruiken
en SHALL niet afhankelijk zijn van gebruikers-`$HOME`. Handmatige uitvoering SHALL beschikbaar zijn als
`~/bin/wake-bobadela1`, verwijzend naar diezelfde bron.

#### Scenario: Service gebruikt store-pad

- **WHEN** de systeemservice als root start
- **THEN** draait die de wake-binary vanuit een store-pad, ongeacht of `/home` beschikbaar is

#### Scenario: Handmatig wekken

- **WHEN** de gebruiker `wake-bobadela1` vanuit de shell uitvoert
- **THEN** draait dezelfde logica als de systeemservice, standaard zonder Signal-notificatie
