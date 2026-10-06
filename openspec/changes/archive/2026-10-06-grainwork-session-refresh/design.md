## Context

oauth2-proxy (provider `oidc`) bewaart na de login een versleutelde sessiecookie `_grainwork` (30 dagen). Zonder `cookie-refresh` wordt die sessie nooit opnieuw bij Pocket ID getoetst.

## Decisions

- **`cookie.refresh = "1h0m0s"` + scope `offline_access`.** Pocket ID geeft dan een refresh-token. Bij een verzoek met een sessie ouder dan een uur haalt oauth2-proxy nieuwe tokens op en leest de claims (incl. `groups`) opnieuw; `allowed_groups=grainwork` toetst daarna de nieuwe groepen. Faalt de refresh (account uit, token ingetrokken), dan vervalt de sessie en volgt een nieuwe login. Eén uur is een afweging tussen snel intrekken en het aantal refreshes; deelnemers merken er niets van.
- **`approvalPrompt = "auto"`** in plaats van `force`: het toestemmingsscherm van Pocket ID verschijnt alleen als er nog geen toestemming is.
- **`whitelist-domain = id.dutchyland.net`**: oauth2-proxy weigert standaard `rd=` naar een ander domein. De uitlog-link wordt `/oauth2/sign_out?rd=https://id.dutchyland.net/api/oidc/end-session` (endpoint uit de OIDC-discovery): eerst de sitecookie weg, dan de Pocket ID-sessie.

## Tests

- VM-test: autorisatie-URL bevat `offline_access` en `approval_prompt=auto`; `/oauth2/sign_out?rd=…end-session` stuurt door naar Pocket ID en wist de cookie.
- Eval-test: `cookie.refresh`, scope, approval-prompt en whitelist op de malandro-config.

## Risks / Trade-offs

- **[Tot een uur na intrekken nog toegang]** → acceptabel voor deze site; korter kan via `cookie.refresh`.
