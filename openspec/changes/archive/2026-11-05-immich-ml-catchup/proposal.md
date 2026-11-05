## Why

Immich-ML draait op lobos (`immich-ml-on-lobos`). Uploads terwijl lobos uit is of slaapt krijgen
geen zoekdata en gezichten; nu moet de beheerder dan handmatig Queues → Missing klikken. Bean:
`nixos-h8zb`.

## What Changes

- Timer `immich-ml-catchup` op malandro (elke 10 min): pingt `http://10.77.0.2:3003/ping`. Is ML
  net terug (vorige run "down"), is dit de eerste run, of is de laatste start ouder dan 6 uur, dan
  start hij via de Immich-API `PUT /api/jobs/{smartSearch,faceDetection}` met
  `{"command":"start","force":false}` (= Missing). Gezichten clusteren volgt vanzelf.
- Admin-API-sleutel met alleen `job.create`, als agenix-secret `immich-ml-catchup-key.age`. Zonder
  dat bestand staat de timer uit (build-warning), zoals bij Nebula.
- Test als flake-check `checks.x86_64-linux.immich-ml-catchup`: het script tegen een nep-server.

## Capabilities

### Modified Capabilities

- `immich-photos`: nieuwe requirement "ML-werk inhalen als lobos terug is".

## Impact

- Nieuw: `modules/immich-ml-catchup/` (module, script, test), regel in `secrets/secrets.nix`,
  check in `flake.nix`, import in `hosts/malandro/configuration.nix`.
- Handmatig: sleutel aanmaken in Immich en versleutelen (`docs/immich.md`).
