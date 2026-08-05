## ADDED Requirements

### Requirement: Authelia functioneert als OIDC identity provider
Authelia SHALL geconfigureerd zijn als OIDC identity provider met `identity_providers.oidc` sectie actief in `modules/authelia.nix`, inclusief de vereiste agenix secrets voor HMAC en issuer private key.

#### Scenario: OIDC discovery endpoint bereikbaar
- **WHEN** een OIDC client het discovery endpoint opvraagt
- **THEN** antwoordt `https://auth.toorren.net/.well-known/openid-configuration` met de juiste metadata

#### Scenario: Authelia secrets geladen
- **WHEN** Authelia opstart
- **THEN** zijn `oidcHmacSecretFile` en `oidcIssuerPrivateKeyFile` beschikbaar via agenix secrets

### Requirement: Wallos is geregistreerd als OIDC client bij Authelia
Authelia SHALL een OIDC client bevatten met id `wallos`, met de Wallos redirect URI en een argon2id-gehashte client secret.

#### Scenario: OIDC authorization flow
- **WHEN** Wallos een authorization request stuurt naar Authelia
- **THEN** herkent Authelia de client id `wallos` en verwerkt de request

#### Scenario: Redirect URI validatie
- **WHEN** Authelia na authenticatie terugstuurt naar Wallos
- **THEN** is de redirect URI `https://subscriptions.toorren.net/index.php` geregistreerd en toegestaan

#### Scenario: Scopes beschikbaar
- **WHEN** Wallos inlogt met scopes `openid email profile`
- **THEN** geeft Authelia een token terug met de aangevraagde claims

### Requirement: OIDC client secret veilig opgeslagen
De plain-text client secret voor Wallos SHALL opgeslagen worden in `secrets/wallos-env.age`. De bijbehorende argon2id hash SHALL inline staan in de Authelia Nix configuratie (hash is niet geheim).

#### Scenario: Secret beschikbaar voor Wallos container
- **WHEN** de wallos container start
- **THEN** is `OIDC_CLIENT_SECRET` beschikbaar via de agenix env-file

#### Scenario: Hash correct in Authelia config
- **WHEN** Wallos een token request doet met de plain-text secret
- **THEN** valideert Authelia dit succesvol tegen de opgeslagen argon2id hash
