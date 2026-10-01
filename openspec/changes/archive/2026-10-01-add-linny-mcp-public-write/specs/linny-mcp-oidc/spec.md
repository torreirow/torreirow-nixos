# Spec Delta

## MODIFIED Requirements

### Requirement: Het publieke pad is leesgericht

Het token waarmee nginx namens geauthenticeerde clients bij linny-mcp aanklopt SHALL standaard
alleen leesrechten dragen. Een expliciete, standaard-uitgeschakelde schakelaar SHALL bepalen of
nginx in plaats daarvan een schrijf-capabel intern token injecteert. Zolang de schakelaar uit
staat SHALL het publieke pad elke schrijfaanroep weigeren.

#### Scenario: Schrijfpoging via de publieke route wordt geweigerd

- **WHEN** de schrijfschakelaar uit staat en een via Authelia geauthenticeerde client `create_doc`
  of `update_doc` aanroept
- **THEN** linny-mcp SHALL de aanroep weigeren wegens ontbrekende schrijfscope

#### Scenario: Schrijven via de publieke route lukt als de schakelaar aan staat

- **WHEN** de schrijfschakelaar aan staat en een client die de vereiste autorisatiepolicy haalt
  `create_doc` of `update_doc` aanroept
- **THEN** nginx SHALL een schrijf-capabel intern token injecteren
- **AND** linny-mcp SHALL de schrijfaanroep uitvoeren

#### Scenario: Het interne token volgt de stand van de schakelaar

- **WHEN** de gegenereerde nginx-configuratie wordt geïnspecteerd in beide standen
- **THEN** de ingevoegde `Authorization`-snippet SHALL verwijzen naar het leestoken als de
  schakelaar uit staat en naar het schrijftoken als de schakelaar aan staat
- **AND** in geen van beide standen SHALL een tokenwaarde in de nginx-configuratie staan

#### Scenario: Schrijven blijft mogelijk via de tunnel

- **WHEN** een client via de ssh-tunnel met het schrijfbare token verbindt
- **THEN** het gedrag uit `linny-mcp-hosting` SHALL gelden, ongeacht de stand van de publieke
  schrijfschakelaar

## ADDED Requirements

### Requirement: De publieke route is beperkt tot een benoemde autorisatiepolicy

De publieke OIDC-client SHALL alleen tokens krijgen voor gebruikers die een benoemde Authelia
authorization policy halen — zowel een tweede factor als lidmaatschap van de beheerdersgroep —
en SHALL NOT een token afgeven aan elke gebruiker die enkel een tweede factor doorloopt.

#### Scenario: Gebruiker buiten de beheerdersgroep krijgt geen token

- **WHEN** een Authelia-gebruiker die geen lid is van de beheerdersgroep de connector-client
  autoriseert, ook al doorloopt die een tweede factor
- **THEN** Authelia SHALL de autorisatie weigeren en SHALL NOT een access token voor deze client
  afgeven

#### Scenario: Beheerder met tweede factor krijgt wel een token

- **WHEN** een gebruiker uit de beheerdersgroep de connector-client autoriseert met een tweede
  factor
- **THEN** Authelia SHALL een access token afgeven
- **AND** de publieke route SHALL de bijbehorende aanroepen doorlaten
