## ADDED Requirements

### Requirement: blocky.toorren.net valt onder de operations-groep

Het domein `blocky.toorren.net` (de blocky-ui) SHALL via een expliciete `access_control`-regel aan
de groep `operations` worden toegekend met `policy = two_factor`, in lijn met de overige
infra-/sysadmin-diensten (cockpit, fail2ban, status, zigbee2mqtt, pdftools). Er SHALL geen aparte
of ruimere regel voor dit domein bestaan.

#### Scenario: Operations-lid krijgt toegang

- **WHEN** een lid van `group:operations` met voltooide 2FA `https://blocky.toorren.net` bezoekt
- **THEN** SHALL Authelia de toegang toestaan en de request naar de blocky-ui doorlaten

#### Scenario: Niet-operations-gebruiker geweigerd

- **WHEN** een ingelogde gebruiker die niet in `group:operations` zit `blocky.toorren.net` bezoekt
- **THEN** SHALL Authelia de toegang weigeren (403)

#### Scenario: Gedekt door precies één expliciete regel

- **WHEN** de access_control-regels worden vergeleken met de forward-auth-beschermde vhosts
- **THEN** SHALL `blocky.toorren.net` door precies één expliciete domein-regel worden gedekt
  (de `operations`-regel), zonder wildcard
