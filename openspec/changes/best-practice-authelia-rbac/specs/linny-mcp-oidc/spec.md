# Spec Delta

## MODIFIED Requirements

### Requirement: De publieke route is beperkt tot een benoemde autorisatiepolicy

De publieke OIDC-client SHALL alleen tokens krijgen voor gebruikers die een benoemde Authelia
authorization policy halen — zowel een tweede factor als lidmaatschap van de Linny-groep
(`linny`) — en SHALL NOT een token afgeven aan elke gebruiker die enkel een tweede factor
doorloopt.

#### Scenario: Gebruiker buiten de Linny-groep krijgt geen token

- **WHEN** een Authelia-gebruiker die geen lid is van de Linny-groep de connector-client
  autoriseert, ook al doorloopt die een tweede factor
- **THEN** Authelia SHALL de autorisatie weigeren en SHALL NOT een access token voor deze client
  afgeven

#### Scenario: Lid van de Linny-groep met tweede factor krijgt wel een token

- **WHEN** een gebruiker uit de Linny-groep de connector-client autoriseert met een tweede
  factor
- **THEN** Authelia SHALL een access token afgeven
- **AND** de publieke route SHALL de bijbehorende aanroepen doorlaten
