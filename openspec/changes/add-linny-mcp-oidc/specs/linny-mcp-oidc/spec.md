## ADDED Requirements

### Requirement: Authelia authenticeert MCP-clients als OpenID Connect-provider

De MCP-vhost SHALL toegang verlenen op grond van een door Authelia uitgegeven OAuth 2.0
access token, en SHALL NOT vertrouwen op geheimhouding van een URL of op een statisch token dat
door de client wordt aangeleverd.

#### Scenario: Geldig Authelia-token wordt doorgelaten

- **WHEN** een client `/mcp` aanroept met `Authorization: Bearer <geldig authelia_at_ token>`
- **THEN** nginx SHALL het token via `auth_request` bij Authelia's authz-endpoint valideren
- **AND** bij een 200 het verzoek doorzetten naar linny-mcp op de loopback

#### Scenario: Ontbrekend of ongeldig token wordt geweigerd

- **WHEN** een client `/mcp` aanroept zonder token, met een onzinnig token, of met een
  ingetrokken of verlopen token
- **THEN** de vhost SHALL met 401 antwoorden
- **AND** SHALL NOT naar linny-mcp doorzetten

#### Scenario: Geen browserredirect voor API-clients

- **WHEN** een MCP-client zonder geldige sessie `/mcp` aanroept
- **THEN** de vhost SHALL met 401 antwoorden en SHALL NOT met 302 naar het Authelia-portaal
  verwijzen; een MCP-client volgt geen redirect naar HTML

### Requirement: De vhost publiceert waar geauthenticeerd moet worden

De vhost SHALL de OAuth-discovery aanbieden die het MCP-authspec beschrijft, ongeacht of de
gebruikte client er gebruik van maakt.

#### Scenario: WWW-Authenticate op een 401

- **WHEN** de vhost een verzoek met 401 afwijst
- **THEN** het antwoord SHALL een `WWW-Authenticate: Bearer`-header bevatten met een
  `resource_metadata`-verwijzing naar de protected-resource-metadata van deze host

#### Scenario: Protected-resource-metadata is opvraagbaar

- **WHEN** `/.well-known/oauth-protected-resource` wordt opgevraagd
- **THEN** de vhost SHALL een JSON-document teruggeven dat Authelia als authorization server aanwijst
- **AND** dit document SHALL zonder authenticatie leesbaar zijn

### Requirement: Het interne token blijft buiten de nix-store

Het statische token waarmee nginx zich bij linny-mcp meldt SHALL NOT in een wereldleesbaar
store-pad belanden.

#### Scenario: Nginx-config bevat geen tokenliteral

- **WHEN** de gegenereerde nginx-configuratie wordt geïnspecteerd
- **THEN** deze SHALL geen tokenwaarde bevatten
- **AND** de `Authorization`-header SHALL worden gezet vanuit een bestand dat bij activatie wordt
  ontsleuteld, eigendom van de nginx-user en niet leesbaar voor anderen

### Requirement: Het publieke pad is leesgericht

Het token waarmee nginx namens geauthenticeerde clients bij linny-mcp aanklopt SHALL alleen
leesrechten dragen.

#### Scenario: Schrijfpoging via de publieke route wordt geweigerd

- **WHEN** een via Authelia geauthenticeerde client `create_doc` of `update_doc` aanroept
- **THEN** linny-mcp SHALL de aanroep weigeren wegens ontbrekende schrijfscope

#### Scenario: Schrijven blijft mogelijk via de tunnel

- **WHEN** een client via de ssh-tunnel met het schrijfbare token verbindt
- **THEN** het bestaande gedrag uit `linny-mcp-hosting` SHALL ongewijzigd blijven, inclusief
  quarantaine op nieuwe documenten
