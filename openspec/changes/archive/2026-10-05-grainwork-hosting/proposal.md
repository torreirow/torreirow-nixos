## Why

GrainWork (repo `torreirow/grainwork`) is een besloten bijbelstudiesite voor mannen. Hij moet op malandro draaien, zoals wereldvanbegrip, maar alleen bereikbaar zijn voor uitgenodigde deelnemers. De groep groeit via het netwerk van de beheerder, dus accounts moeten via een GUI te beheren zijn, met passkeys in plaats van wachtwoorden. Authelia (`main`) beschermt de homelab-diensten en moet daar los van blijven.

## What Changes

- Nieuwe module `modules/grainwork.nix` met drie schakelaars:
  - `services.grainwork.enable`: wildcard-certificaat `*.dutchyland.net` via CNAME-delegatie naar Route53 (zoals cckafe.com).
  - `pocketId.enable` (fase 1): Pocket ID op `id.dutchyland.net`, Postgres via een agenix-connection-string, alleen op loopback, met een **setup-slot** (alleen thuis-LAN en WireGuard) tot de eerste admin bestaat.
  - `site.enable` (fase 2): `grainwork.dutchyland.net` met webroot `/var/www/grainwork` achter oauth2-proxy (OIDC naar Pocket ID, alleen groep `grainwork`). `/welkom/` en statische assets blijven zonder login bereikbaar.
- Vier agenix-secrets: DB-connection-string en OIDC-client (door de beheerder), encryption key en cookie secret (willekeurig gegenereerd).
- VM-test `checks.x86_64-linux.grainwork` (nginx + Pocket ID + oauth2-proxy) en een eval-test `modules/grainwork_test.py` op de malandro-config.
- malandro importeert de module; de schakelaars staan uit tot de handmatige stappen (CNAME, DB-secret) gedaan zijn.
- `PORTS.md`: 8098 (Pocket ID) en 8099 (oauth2-proxy).

## Capabilities

### New Capabilities
- `grainwork-hosting`: certificaat, Pocket ID met setup-slot, en de site achter oauth2-proxy.

### Modified Capabilities
(geen)

## Impact

- Nieuw: `modules/grainwork.nix`, `modules/grainwork_vmtest.nix`, `modules/grainwork_test.py`, `secrets/grainwork-pocket-id-encryption-key.age`, `secrets/grainwork-oauth2-proxy-cookie.age`
- Gewijzigd: `flake.nix` (`checks`), `hosts/malandro/configuration.nix` (import + schakelaars), `secrets/secrets.nix`, `PORTS.md`
- Handmatig (beheerder): CNAME bij OpenProvider, `secrets/grainwork-pocket-id-db.age`, Pocket ID-setup in de GUI, daarna `secrets/grainwork-oauth2-proxy-client.age`

## Niet-doelen

- Authelia `main` of zijn gebruikers aanpassen.
- De site-inhoud of het release-script (repo `grainwork`).
- Pocket ID-instellingen die in de GUI horen (SMTP, branding, groepen, OIDC-clients) declaratief maken.
