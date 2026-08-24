## Why

Wallos is een self-hosted subscription tracker waarmee abonnementen en terugkerende uitgaven bijgehouden kunnen worden. Door het toe te voegen aan malandro is het beschikbaar via de bestaande infrastructuur, met login via Authelia OIDC (geen apart Wallos-wachtwoord), data op de externe schijf en een gedeelde MariaDB-database.

## What Changes

- Nieuwe NixOS module `modules/wallos.nix` voor de Wallos Docker container
- MariaDB uitbreiden met database `wallos` en gebruiker `wallos`
- MariaDB configureren om ook op 0.0.0.0 te luisteren (t.b.v. Docker bridge toegang)
- Authelia OIDC identity provider activeren (momenteel uitgecommentarieerd in authelia.nix)
- Wallos als OIDC client registreren bij Authelia
- Nieuwe agenix secrets: `wallos-env.age` (DB + OIDC credentials), `authelia-oidc-hmac-secret.age`, `authelia-oidc-issuer-private-key.age`
- Nginx virtualHost `subscriptions.toorren.net` als transparante proxy (geen forward-auth — Wallos regelt login via OIDC)
- Persistent data op `/data/external/wallos/db` en `/data/external/wallos/logos`
- `PORTS.md` bijwerken met poort 8095
- Import toevoegen aan `hosts/malandro/configuration.nix`

## Capabilities

### New Capabilities

- `wallos-service`: Wallos subscription tracker als OCI container op poort 8095, bereikbaar via subscriptions.toorren.net, login via Authelia OIDC (geen eigen login), MariaDB als database, persistent data op /data/external/wallos
- `authelia-oidc`: Authelia als OIDC identity provider activeren met de Wallos applicatie als eerste OIDC client; vereist twee nieuwe agenix secrets (HMAC + private key) en een Wallos client-registratie

### Modified Capabilities

- `mariadb-service`: MariaDB moet ook op 0.0.0.0 luisteren met iptables-regel voor Docker bridge, zodat containers via host.docker.internal verbinding kunnen maken

## Impact

- `modules/wallos.nix` — nieuw bestand
- `modules/authelia.nix` — OIDC identity provider activeren + Wallos client toevoegen
- `hosts/malandro/configuration.nix` — import toevoegen
- `modules/mariadb.nix` — bind-address en firewall uitbreiden
- `PORTS.md` — poort 8095 documenteren
- `secrets/wallos-env.age` — nieuw (DB credentials + OIDC client secret)
- `secrets/authelia-oidc-hmac-secret.age` — nieuw
- `secrets/authelia-oidc-issuer-private-key.age` — nieuw (RSA private key)
- MariaDB herstart vereist na bind-address wijziging
- Authelia herstart vereist na OIDC activatie
