# Proposal

## Why

De MCP-connector vraagt meerdere keren per dag om opnieuw te autoriseren. Gemeten op 2026-09-29,
volledige autorisatierondes voor `claude-connector`:

```
09:10:05   13:33:18   16:13:36   19:08:06   21:48:56
```

Dezelfde Authelia, andere client: `wallos` deed dat op 25 sep, 13 sep, 4 sep en 29 aug.

De gaten tussen die rondes waren 4u23, 2u40 en 2u55 — allemaal ruim boven de levensduur van de
refresh-token (1u30). In redis stonden 1766 sessiesleutels, allemaal met een resterende levensduur
onder een uur: de vingerafdruk van voortdurend opnieuw inloggen.

Twee instellingen veroorzaken dat, en **geen van beide is ooit bewust gekozen**:

- `refresh_token` staat op Authelia's standaard van 90 minuten;
- `consent_mode: explicit` is blijven staan nadat de scope die het verplichtte werd losgelaten
  (`authelia.bearer.authz`, zie de gearchiveerde change `add-linny-mcp-oidc`). Authelia's eigen
  standaard is `auto`, en die kiest `pre-configured` zodra er een duur is opgegeven.

Voor een gekoppelde app is elke ochtend opnieuw verbinden geen acceptabel gedrag.

## What Changes

- Eigen lifespan-profiel voor de connector-client: `access_token` **ongewijzigd** op `1h`,
  `refresh_token` naar `30d`.
- `consent_mode` van `explicit` naar `pre-configured`, met een duur van `1M` — gelijk aan Wallos.
- Toets op `modules/authelia.nix`, dat nu geen enkele test heeft terwijl het alle vhosts beschermt.
- `docs/linny-mcp.md` krijgt een sectie over de drie klokken en welke waarvan is.

Niet in scope: de sessie-cookie (`inactivity: 5m`, `expiration: 1h`). Zie `design.md`.

## Capabilities

### New Capabilities
- geen

### Modified Capabilities
- `linny-mcp-oidc`: hoe vaak een gebruiker opnieuw moet autoriseren is waarneembaar gedrag van de
  koppeling, geen implementatiedetail. Er komt een requirement bij over het behoud van de koppeling
  bij regelmatig gebruik, en over wanneer een onthouden toestemming vervalt.

## Impact

- Alles speelt zich af in `modules/authelia.nix`. Dat bestand fronts ook Nextcloud, Grafana,
  Home Assistant en Wallos; een fout daar treft alles. Op 2026-09-25 legde een wijziging in dit
  bestand alle vhosts vier minuten plat.
- De bewering "bij dagelijks gebruik nooit meer opnieuw autoriseren" is op het moment van uitrollen
  niet te bewijzen. Er wordt een nulpunt vastgelegd en na enkele dagen hergeteld.
