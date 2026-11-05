---
# nixos-esgu
title: Immich machine learning op lobos draaien (remote ML voor malandro)
status: todo
type: feature
priority: low
created_at: 2026-11-05T10:19:50Z
updated_at: 2026-11-05T10:19:50Z
parent: nixos-ypet
---

Immich op malandro heeft ML uit: de Celeron J3455 heeft geen AVX. Lobos (Ryzen 7 PRO 7840U, AVX2) kan de immich-machine-learning-dienst draaien en malandro gebruikt die als remote ML-URL (Admin → Machine Learning → URL).

Uitzoeken:
- services.immich.machine-learning los op lobos (zonder de rest van Immich), poort 3003
- bereikbaarheid vanaf malandro: Nebula-IP van lobos of LAN; firewall alleen voor malandro openen
- lobos is een laptop en vaak uit/in slaap: Immich zet ML-jobs dan in de wachtrij; controleren dat dat geen fouten-storm geeft
- daarna Smart Search, gezichtsherkenning en dubbele-foto-detectie in Immich aanzetten

Zie docs/immich.md.
