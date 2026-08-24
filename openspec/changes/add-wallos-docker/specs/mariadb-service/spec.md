## ADDED Requirements

### Requirement: MariaDB accepteert TCP verbindingen van Docker containers
MariaDB SHALL geconfigureerd zijn met `bind-address = "0.0.0.0"` zodat Docker containers verbinding kunnen maken via `host.docker.internal:3306`.

#### Scenario: Docker container verbinding met MariaDB
- **WHEN** een Docker container verbinding maakt met `host.docker.internal:3306`
- **THEN** accepteert MariaDB de verbinding

#### Scenario: Firewall staat Docker bridge toe
- **WHEN** een Docker container een TCP verbinding opent naar poort 3306
- **THEN** laat de iptables-regel op `br+` interfaces dit toe

### Requirement: Wallos database en gebruiker aanwezig in MariaDB
MariaDB SHALL een database `wallos` bevatten en een gebruiker `wallos` met ALL PRIVILEGES op `wallos.*`.

#### Scenario: Database bestaat na nixos-rebuild
- **WHEN** `nixos-rebuild switch` succesvol is uitgevoerd
- **THEN** bestaat de database `wallos` in MariaDB

#### Scenario: Gebruiker heeft rechten
- **WHEN** de wallos MariaDB user verbinding maakt
- **THEN** heeft hij volledige rechten op de `wallos` database

### Requirement: Bestaande services niet onderbroken door bind-address wijziging
De wijziging van `bind-address` SHALL geen impact hebben op bestaande services die MariaDB via socket gebruiken (Castopod, InvoicePlane native).

#### Scenario: Socket verbindingen blijven werken
- **WHEN** MariaDB herstart is na de configuratiewijziging
- **THEN** werken Castopod en InvoicePlane nog steeds correct via socket-authenticatie
