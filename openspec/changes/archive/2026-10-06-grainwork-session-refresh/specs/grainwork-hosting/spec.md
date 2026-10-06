## MODIFIED Requirements

### Requirement: OIDC naar Pocket ID
oauth2-proxy SHALL Pocket ID op `id.dutchyland.net` als OIDC-provider gebruiken, met de scopes `openid email profile groups offline_access`, PKCE (S256), client-id en -secret uit een agenix-env-bestand, en een sessiecookie die 30 dagen geldig is. Het toestemmingsscherm SHALL alleen verschijnen als er nog geen toestemming is gegeven.

#### Scenario: Inloggen starten
- **WHEN** een bezoeker `/oauth2/start` opent
- **THEN** wordt hij doorgestuurd naar `https://id.dutchyland.net/authorize` met de client-id van GrainWork, scope `groups` en `offline_access`, `code_challenge_method=S256` en zonder geforceerde toestemming

## ADDED Requirements

### Requirement: Ingetrokken toegang binnen een uur
oauth2-proxy SHALL een sessie die ouder is dan een uur bij het volgende verzoek verversen bij Pocket ID en daarbij de groep opnieuw toetsen. Een uitgezet account of een deelnemer die uit de groep `grainwork` is gehaald, SHALL daarna geen toegang meer hebben.

#### Scenario: Uit de groep gehaald
- **WHEN** de beheerder een deelnemer uit de groep `grainwork` haalt en er meer dan een uur verstrijkt
- **THEN** krijgt die deelnemer bij zijn volgende bezoek geen toegang meer

### Requirement: Uitloggen
`/oauth2/sign_out` SHALL de sessiecookie van de site wissen en, als `rd` naar `id.dutchyland.net` wijst, daarheen doorsturen zodat ook de Pocket ID-sessie eindigt. Doorsturen naar andere domeinen SHALL geweigerd blijven.

#### Scenario: Uitlog-link
- **WHEN** een deelnemer `/oauth2/sign_out?rd=https://id.dutchyland.net/api/oidc/end-session` opent
- **THEN** is de cookie `_grainwork` gewist en komt hij bij het uitlogscherm van Pocket ID
