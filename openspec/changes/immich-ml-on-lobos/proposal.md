## Why

Immich op malandro draait zonder machine learning: de Celeron J3455 heeft geen AVX, en de
ML-dienst (ONNX) eist dat. Daardoor werken slim zoeken ("strand", "hond"), gezichtsherkenning en
dubbele-foto-detectie niet. Lobos (Ryzen 7 PRO 7840U, AVX2) kan de ML-dienst wel draaien, en
Immich ondersteunt een externe ML-URL. Bean: `nixos-esgu`.

## What Changes

- Lobos draait alleen `immich-machine-learning` (zelfde versie als de server, uit `unstable`), op
  poort 3003, zonder de rest van Immich. Laag geprioriteerd (nice/idle-I/O) zodat de laptop
  interactief blijft.
- De poort is alleen bereikbaar via de Nebula-mesh, en alleen voor host `malandro`
  (Nebula-firewallregel in `modules/nebula.nix`).
- Immich op malandro zet ML aan met `urls = [ "http://10.77.0.2:3003" ]`; slim zoeken,
  gezichtsherkenning en dubbele-detectie gebruiken die.
- Lobos uit of in slaap: de availability-check markeert de URL als unhealthy (één logregel per
  wisseling); ML-taken van nieuwe uploads mislukken en worden later met "Ontbrekende" opnieuw
  gedraaid. Geen automatische herstart van jobs (vervolg-bean).

## Capabilities

### Modified Capabilities

- `immich-photos`: de requirement "Machine learning uit, video op de CPU" krijgt de inhoud
  "ML niet op malandro maar op lobos, via Nebula"; de naam blijft (met "uit" = uit op malandro).

## Impact

- Nieuw: `modules/immich-ml.nix` (import in `hosts/lobos/configuration.nix`).
- Gewijzigd: `modules/nebula.nix` (inbound 3003/tcp van malandro op lobos), `modules/immich.nix`
  (ML-settings), `docs/immich.md`, `PORTS.md`.
- Lobos: modellen in `/var/cache/immich-ml` (~1 GB), RAM alleen tijdens ML-werk (model-TTL).
