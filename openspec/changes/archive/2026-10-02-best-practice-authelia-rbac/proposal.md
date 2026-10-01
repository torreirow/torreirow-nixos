# Proposal

## Why

De Authelia-autorisatie op malandro leunt op één `*.toorren.net`-catch-all die aan `group:admins`
hangt. Dat overlaadt `admins` (bereik tot álles + impliciete "rol" die geen enkele app leest),
maakt nieuwe vhosts automatisch admin-bereikbaar in plaats van default-deny, en vermengt het
admin-account met dagelijks gebruik. Grafana geeft bovendien iederéén die binnenkomt org-Admin.
Voor meer gebruikers is dit niet houdbaar: toegang hoort expliciet, per dienst, per groep, met een
admin-account dat gescheiden is van dagelijks gebruik.

## What Changes

- **Wildcard weg.** De `*.toorren.net`-regel en de groep `admins` vervallen. `default_policy`
  blijft `deny`; elke forward-auth-dienst krijgt een **expliciete per-domein regel** op een
  betekenisvolle toegangsgroep. Twee bestaande gaten (`alertmanager`, `agenda` — nu alleen via de
  wildcard) worden meteen gedicht. **BREAKING**: een dienst zonder expliciete regel is voortaan
  dicht.
- **Toegangsgroepen**: `monitoring` (prometheus, alertmanager), `network` (wg), `operations`
  (cockpit, fail2ban, status, zigbee2mqtt, pdftools, vw `/admin`), `office` (docs, contacts, mmdl,
  ittools), `linny` (linny-webview), `personal-wouter` (wouter.toorren.net, agenda). Grafana-bereik
  loopt via de rol-groepen hieronder, niet via `monitoring`.
- **`LinnyWouter` → `linny`.** De groep wordt hernoemd; de `linny.toorren.net`-regel en de
  `linny-mcp-write` OIDC-policy wijzen voortaan naar `group:linny`.
- **Grafana van proxy-auth naar OIDC.** `auth.proxy` + `X-WEBAUTH-USER` + `auto_assign_org_role =
  Admin` verdwijnen. Grafana wordt een OIDC-client op Authelia met `role_attribute_path` dat
  `grafana-admins` → Admin en `grafana-editors` → Editor mapt, anders Viewer. Bereik én rol lopen via
  die rol-groepen (niet via `monitoring`). Nieuw agenix client-secret. **BREAKING**: einde "iedereen
  is Grafana-Admin".
- **Gescheiden admin-account.** Nieuw account **`wouteradmin`** (privileged): `monitoring`,
  `network`, `operations`, `office`, `grafana-admins`. **`wouter`** wordt een gewone gebruiker
  zónder admin: `office`, `linny`, `personal-wouter`, `grafana-editors` (Grafana-Editor).
  **`wouteruser`**: `office`, `linny`.
- **Paperless-rollen herkoppeld (runtime).** `wouteradmin` wordt de Paperless-superuser; `wouter`
  wordt gedegradeerd tot gewone Paperless-gebruiker; `wouteruser` blijft gewoon. Dit is een
  DB-/runtime-actie (Paperless draait als container buiten de repo); Paperless kent geen
  group→superuser-mapping, dus geen `paperless-admins`-groep.

## Capabilities

### New Capabilities
- `authelia-access-control`: het malandro-autorisatiemodel — expliciete per-domein toegang op
  betekenisvolle groepen (deny-by-default, geen wildcard), de scheiding tussen een privileged
  admin-account en dagelijkse accounts, en group→rol-mapping voor apps die het ondersteunen
  (Grafana via OIDC).

### Modified Capabilities
- `linny-mcp-oidc`: de connector-policy en de Linny-toegang hangen voortaan aan `group:linny`
  in plaats van `group:LinnyWouter`/`group:admins`.

## Impact

- `modules/authelia.nix`: access_control herschreven (expliciete regels, wildcard weg),
  `authorization_policies` (linny → `group:linny`), nieuwe Grafana-OIDC-client.
- `hosts/malandro/configuration.nix`: `services.authelia.users` — `wouteradmin` erbij, `wouter`/
  `wouteruser` groepen herzien, `admins` verdwijnt.
- `modules/monitoring/grafana/grafana.nix` + `modules/monitoring/default.nix`: Grafana OIDC i.p.v.
  auth.proxy; vhost-headers aangepast.
- `modules/linny-mcp.nix`: commentaar/policy-naam `linny`.
- `secrets/`: nieuw `grafana-oidc-secret.age` + recipient in `secrets/secrets.nix`.
- Runtime (malandro, buiten repo): Paperless-superuser verplaatsen; `wouteradmin` argon2-hash +
  2FA-enrollment.
- `docs/linny-mcp.md`, `CLAUDE.md`, `CHANGELOG.md` bijgewerkt.
- Migratie is lockout-gevoelig: groepen/accounts + alle expliciete regels moeten vóór het
  verwijderen van de wildcard staan, in één switch, met geteste rollback.
