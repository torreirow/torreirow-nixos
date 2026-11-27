# Tasks

## 1. Manifest in plaats van kopieën

- [x] 1.1 `modules/cckafe-photos/fetch.sh` ontdoen van het downloaden, verkleinen en
      verplaatsen van fotobestanden: per album alleen nog `id`, `width`, `height`, `v` en
      `source` in `manifest.json` schrijven; verifieer dat een run geen fotobestanden in
      `PHOTOS_DIR` achterlaat
- [x] 1.2 De afmetingen berekenen uit de verhouding van het origineel en de korte zijde van
      800 (`fit: outside`, niet vergroten); verifieer met een liggende (2400×1600 →
      1200×800) en een staande foto (1400×2100 → 800×1200)
- [x] 1.3 `imagemagick` uit `runtimeInputs` in `package.nix` halen; verifieer dat
      `nix build .#checks.x86_64-linux.cckafe-photos` slaagt zonder die afhankelijkheid
- [x] 1.4 De tests in `test.nix` en `stub_server.py` omzetten naar het nieuwe gedrag:
      manifest met asset-id's, geen fotobestanden, album ontbreekt laat het vorige manifest
      staan; verifieer dat de check groen is

## 2. Proxy in nginx

- [x] 2.1 Een age-secret `secrets/immich-cckafe-photos-nginx-key.age` toevoegen met de
      regel `proxy_set_header x-api-key "…";`, ontvangers bijwerken in `secrets/secrets.nix`,
      eigenaar `nginx`, mode `0400`; verifieer dat het bestand te ontsleutelen is en dat de
      tokenwaarde niet in de nix-store staat
- [x] 2.2 In `modules/cckafe.nix` een locatie `^~ /immich/` toevoegen die
      `<uuid>.webp` herschrijft naar `/api/assets/<uuid>/thumbnail?size=preview` en proxyt
      naar `127.0.0.1:2283`, met het secret-snippet geïnclude; verifieer dat een
      asset-id een `image/webp` oplevert en een willekeurig pad een 404
- [x] 2.3 De `alias` op `^~ /photos/` laten staan voor de manifesten en de cache-headers
      gelijktrekken; verifieer dat `/photos/<slug>/manifest.json` 200 blijft geven
- [x] 2.4 Op malandro `nixos-rebuild switch` en controleren dat `/immich/<id>.webp` via
      cckafe.com een WebP van ~155 kB teruggeeft en dat er geen sleutel in het antwoord staat

## 3. Afronden

- [x] 3.1 `docs/cckafe-photos.md` herschrijven: geen kopieën, wel de proxy, de
      Immich-afhankelijkheid en de load-berekening
- [x] 3.2 Na de omschakeling de oude `.webp`-bestanden onder `/var/lib/cckafe-photos/`
      verwijderen; verifieer dat alleen `manifest.json` per album overblijft en dat de
      galerij op test.cckafe.com de foto's nog toont
- [x] 3.3 `nix build .#checks.x86_64-linux.cckafe-photos` en
      `openspec validate cckafe-photos-proxy --strict`; verifieer dat beide groen zijn
