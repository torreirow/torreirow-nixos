## Why

oauth2-proxy geeft na het inloggen een eigen sessiecookie van 30 dagen. Uitloggen bij Pocket ID, een account uitzetten of iemand uit de groep `grainwork` halen heeft daar geen invloed op: wie de cookie heeft, houdt tot 30 dagen toegang tot GrainWork. Daarnaast vraagt Pocket ID bij elke login opnieuw om toestemming (`approval_prompt=force`), en is er geen manier om in één keer overal uit te loggen.

## What Changes

- oauth2-proxy ververst de sessie elk uur met een refresh-token (scope `offline_access`); daarbij worden account en groep opnieuw gecontroleerd. Ingetrokken toegang werkt dus binnen een uur, terwijl deelnemers 30 dagen ingelogd blijven.
- `approval_prompt=auto`: toestemming alleen de eerste keer.
- `/oauth2/sign_out` mag doorsturen naar `id.dutchyland.net`, zodat een uitlog-link de sitecookie wist én bij Pocket ID uitlogt.

## Capabilities

### New Capabilities
(geen)

### Modified Capabilities
- `grainwork-hosting`: sessie-verversing, toestemming en uitloggen.

## Impact

- `modules/grainwork.nix` (oauth2-proxy-instellingen), `modules/grainwork_test.py`, `modules/grainwork_vmtest.nix`
- Site: de link "Uitloggen" zelf staat in de repo `grainwork` (change `logout-link`).

## Niet-doelen

- Back-channel logout of directe sessie-intrekking (Pocket ID kan oauth2-proxy niet actief informeren).
