---
# nixos-esgu
title: Immich machine learning op lobos draaien (remote ML voor malandro)
status: completed
type: feature
priority: low
created_at: 2026-11-05T10:19:50Z
updated_at: 2026-11-05T11:39:10Z
parent: nixos-ypet
---

Immich op malandro heeft ML uit: de Celeron J3455 heeft geen AVX. Lobos (Ryzen 7 PRO 7840U, AVX2) kan de immich-machine-learning-dienst draaien en malandro gebruikt die als remote ML-URL (Admin → Machine Learning → URL).

Uitzoeken:
- services.immich.machine-learning los op lobos (zonder de rest van Immich), poort 3003
- bereikbaarheid vanaf malandro: Nebula-IP van lobos of LAN; firewall alleen voor malandro openen
- lobos is een laptop en vaak uit/in slaap: Immich zet ML-jobs dan in de wachtrij; controleren dat dat geen fouten-storm geeft
- daarna Smart Search, gezichtsherkenning en dubbele-foto-detectie in Immich aanzetten

Zie docs/immich.md.

## Summary of Changes

- `modules/immich-ml.nix` (lobos): alleen `immich-machine-learning` 3.3.5 uit unstable op 3003, DynamicUser, cache `/var/cache/immich-ml`, Nice 15 + idle-I/O.
- `modules/nebula.nix`: lobos laat 3003/tcp alleen voor host `malandro` toe; VM-test `checks.x86_64-linux.nebula` uitgebreid (malandro mag, mpenzi en underlay niet).
- `modules/immich.nix` (malandro): `machineLearning.urls = [ "http://10.77.0.2:3003" ]`.
- Docs: `docs/immich.md` (sectie "Machine learning op lobos"), `PORTS.md`, index in `CLAUDE.md`. OpenSpec `immich-ml-on-lobos` gearchiveerd.
- Live getest 2026-11-05: malandro meldt de ML-server healthy; na Smart Search (All) en Face Detection (Missing) 31 embeddings, 51 gezichten, 4 personen, 0 mislukte ML-aanvragen. Modellen 919 MB op lobos.
- Vervolg: `nixos-h8zb` (ML-jobs automatisch inhalen als lobos weer online komt).
