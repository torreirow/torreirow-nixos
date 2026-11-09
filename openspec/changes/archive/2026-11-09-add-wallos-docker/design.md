## Context

Malandro draait meerdere Docker-gebaseerde services via NixOS `virtualisation.oci-containers`. Wallos ondersteunt OIDC natively (`OIDC_ENABLED`, `OIDC_DISABLE_PASSWORD_LOGIN`). Authelia heeft een uitgecommentarieerde maar gereed OIDC identity provider configuratie in `modules/authelia.nix`. MariaDB luistert momenteel alleen op socket/localhost.

Twee volumes zijn vereist voor Wallos:
- `/var/www/html/db` — SQLite database (niet gebruikt met MariaDB, maar bevat ook migratie-state) of gewoon de data dir
- `/var/www/html/images/uploads/logos` — subscription logo uploads

## Goals / Non-Goals

**Goals:**
- Wallos toevoegen op subscriptions.toorren.net met MariaDB
- Login uitsluitend via Authelia OIDC — geen eigen Wallos wachtwoord
- Consistent met bestaande OCI container modules
- Authelia OIDC activeren als herbruikbare basis voor toekomstige apps

**Non-Goals:**
- Monitoring/alerting voor Wallos
- Multi-user setup
- OIDC voor andere bestaande services in deze change

## Decisions

### OIDC via Authelia (geen forward-auth)
**Beslissing**: Wallos gebruikt `OIDC_ENABLED=true` + `OIDC_DISABLE_PASSWORD_LOGIN=true` richting Authelia als identity provider. Nginx doet geen forward-auth, alleen transparante proxy.
**Rationale**: Wallos heeft native OIDC support — dit is de correcte manier voor echte SSO. Forward-auth zou Wallos eigen login niet uitschakelen. OIDC geeft ook betere logout-ondersteuning.
**Alternatief overwogen**: Forward-auth only (eenvoudiger, maar Wallos toont nog steeds eigen loginpagina als je de Authelia cookie omzeilt).

### Authelia OIDC activeren in authelia.nix
**Beslissing**: `identity_providers.oidc` sectie in `modules/authelia.nix` uitcommentariëren en uitbreiden met de Wallos client.
**Rationale**: Centraal — alle Authelia config staat in één bestand. Wallos is de eerste OIDC client; de structuur is herbruikbaar voor toekomstige apps.
**Vereiste secrets**: 
- `authelia-oidc-hmac-secret` — willekeurige string (64+ tekens), genereer met `openssl rand -hex 32`
- `authelia-oidc-issuer-private-key` — RSA private key, genereer met `openssl genrsa -out private.key 4096`
- Wallos OIDC client secret — unhashed opslaan in wallos-env.age; Authelia config krijgt de argon2id hash

### OIDC client secret hashing
**Beslissing**: Client secret als plain text in `wallos-env.age`; Authelia krijgt de argon2id hash inline in de Nix config.
**Rationale**: Authelia verwacht een gehashte waarde in de client config. Hash genereren met: `authelia crypto hash generate argon2 --password '<secret>'`. De hash is geen geheim (eenrichtingsfunctie), mag in de Nix store.

### OCI container — twee volumes
**Beslissing**: Twee volume mounts conform Wallos docker-compose.yaml:
- `/data/external/wallos/db:/var/www/html/db`
- `/data/external/wallos/logos:/var/www/html/images/uploads/logos`
**Rationale**: Logos zijn user-uploaded content, los van de database.

### MariaDB bind-address uitbreiden naar 0.0.0.0
**Beslissing**: `services.mysql.settings.mysqld.bind-address = "0.0.0.0"` + iptables-regel voor Docker bridge (`br+`) → port 3306.
**Rationale**: Zelfde patroon als PostgreSQL in `postgres.nix`. Bestaande services (Castopod, InvoicePlane) gebruiken socket-auth en worden niet geraakt.

### MariaDB user/database via ensureDatabases/ensureUsers in wallos.nix
**Beslissing**: `lib.mkAfter` op `services.mysql.ensureDatabases` en `ensureUsers`, zelfde als `vikunja.nix`. Wachtwoord via env-file doorgegeven aan container.
**Rationale**: Declaratief, idempotent. NixOS `ensureUsers` maakt een passwordless socket-user aan — Docker container gebruikt het wachtwoord uit de env-file via TCP.

### Nginx: transparante proxy zonder forward-auth
**Beslissing**: Nginx voor subscriptions.toorren.net alleen reverse proxy, geen `auth_request /authelia`.
**Rationale**: Wallos regelt authenticatie zelf via OIDC redirect. Forward-auth zou conflicteren met de OIDC callback URL.

## Risks / Trade-offs

- [MariaDB herstart na bind-address wijziging] → Kort downtime voor Castopod en InvoicePlane. Buiten piekuren uitvoeren.
- [Authelia herstart na OIDC activatie] → Alle Authelia-beschermde services zijn tijdelijk onbereikbaar. Kort (seconden).
- [OIDC client secret hash in Nix store] → Hash is public-safe (argon2id). Secret zelf staat in agenix.
- [bellamy/wallos:latest — geen gepinde versie] → Image updates kunnen breaking changes bevatten. Kan later worden gepind.
- [OIDC_USER_IDENTIFIER] → Standaard `sub` (Authelia subject). Als de Authelia user wordt verwijderd en opnieuw aangemaakt, krijgt de Wallos user een nieuw account. Acceptabel voor single-user setup.

## Migration Plan

1. Genereer OIDC secrets:
   ```bash
   openssl rand -hex 32  # → authelia-oidc-hmac-secret
   openssl genrsa 4096   # → authelia-oidc-issuer-private-key
   openssl rand -hex 32  # → wallos OIDC client secret (plain)
   authelia crypto hash generate argon2 --password '<client-secret>'  # → hash voor Nix config
   ```
2. Agenix secrets aanmaken: `agenix edit secrets/authelia-oidc-hmac-secret.age` etc.
3. `nixos-rebuild switch --flake .#malandro`
4. Wallos setup wizard doorlopen: kies currency, maak account aan via OIDC login
5. Test: uitloggen → redirect naar Authelia → terugkeer naar Wallos

**Rollback**: Module-import verwijderen en OIDC sectie in authelia.nix terugcommentariëren.

## Open Questions

- Welk wachtwoord voor wallos MariaDB user? → Door gebruiker te kiezen bij aanmaken agenix secret.
- Wallos container port: docker-compose toont 8282 → 80 (nginx inside container). Intern draait het op poort 80. Host mapping wordt 8095:80.
