## ADDED Requirements

### Requirement: RustDesk via het Nebula-IP
mpenzi SHALL RustDesk-verbindingen aannemen via direct IP access op het Nebula-adres 10.77.0.3,
poort 21118, ook als het RustDesk-venster niet open is. Er MUST geen eigen of publieke relay
voor nodig zijn.

#### Scenario: Meekijken vanaf lobos
- **WHEN** Wouter in RustDesk op lobos verbindt met `10.77.0.3`
- **THEN** komt een sessie tot stand nadat Maaike die heeft geaccepteerd of het wachtwoord is
  ingevoerd

### Requirement: RustDesk niet op het gewone netwerk
Poort 21118 MUST NOT bereikbaar zijn via de wifi- of LAN-interface van mpenzi.

#### Scenario: Iemand op hetzelfde wifi
- **WHEN** een ander apparaat op het LAN verbindt met mpenzi op poort 21118
- **THEN** wordt de verbinding geweigerd

### Requirement: Direct IP access standaard aan
mpenzi SHALL direct IP access aanzetten als die optie nog niet is ingesteld. Een keuze die in de
RustDesk-GUI is gemaakt MUST blijven staan.

#### Scenario: Eerste start
- **WHEN** de RustDesk-service voor het eerst start
- **THEN** staat `direct-server = 'Y'` in de RustDesk-config van de service
