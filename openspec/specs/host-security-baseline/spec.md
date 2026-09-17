# host-security-baseline Specification

## Purpose

Legt vast welke controleerbare beveiligingsinstellingen een host minimaal voert — zichtbaarheid van
de actieve firewall, gehardende kernelparameters, en een audit-daemon die daadwerkelijk logt —
zodat de beveiligingspostuur declaratief en auditeerbaar is in plaats van impliciet.

## Requirements

### Requirement: Actieve firewall is extern vaststelbaar

De host SHALL zijn actieve pakketfilter aantoonbaar maken voor externe audittooling, zodat een
audit geen vals negatief oplevert over een firewall die wel degelijk draait.

#### Scenario: Audittool inventariseert de firewall

- **WHEN** een beveiligingsaudit op de host vaststelt welk pakketfilter actief is
- **THEN** wordt de draaiende firewall als actief herkend, en niet als afwezig gerapporteerd

#### Scenario: Filtergedrag blijft ongewijzigd

- **WHEN** de firewall aantoonbaar wordt gemaakt voor audittooling
- **THEN** verandert er niets aan welk verkeer de host toelaat of blokkeert

### Requirement: Gehardende kernelparameters zonder functieverlies

De host SHALL kernelparameters voeren die bestandsbescherming, core-dump-gedrag,
kernel-pointer-restrictie, BPF-JIT-hardening en de afhandeling van ICMP-redirects en
martian-pakketten aanscherpen, voor zover dat de werking van de host niet aantast.

#### Scenario: Aangescherpte parameters zijn actief

- **WHEN** de host is opgestart
- **THEN** zijn de gehardende waarden voor bestandsbescherming, core dumps, kernel-pointers,
  BPF-JIT en ICMP-redirect/martian-afhandeling van kracht

#### Scenario: Bestaande hostfunctionaliteit blijft intact

- **WHEN** gehardende kernelparameters worden toegepast op een host die kernelmodules herlaadt na
  suspend en containernetwerken doorstuurt
- **THEN** blijven het herladen van kernelmodules en het doorsturen van containerverkeer werken,
  omdat parameters die deze functies zouden breken niet worden gezet

### Requirement: Audit-daemon legt daadwerkelijk gebeurtenissen vast

De host SHALL geen audit-daemon draaien met een lege regelset. Draait de daemon, dan SHALL er een
regelset actief zijn die veiligheidsrelevante gebeurtenissen vastlegt.

#### Scenario: Audit-daemon is ingeschakeld

- **WHEN** de audit-daemon op de host draait
- **THEN** is er een niet-lege regelset geladen en worden veiligheidsrelevante gebeurtenissen
  vastgelegd

#### Scenario: Wijziging aan een gevoelig bestand

- **WHEN** een gevoelig systeembestand zoals de gebruikers- of sudo-configuratie wordt gewijzigd
- **THEN** legt de audit-daemon die wijziging vast
