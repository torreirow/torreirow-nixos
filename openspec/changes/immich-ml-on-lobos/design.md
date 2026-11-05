## Context

De NixOS-module `services.immich` zet de ML-dienst alleen naast de server aan (alles zit onder
`mkIf cfg.enable`). Lobos moet alleen de ML-dienst hebben, zonder database, redis en server.

## Decisions

- **Eigen systemd-unit i.p.v. de module.** `modules/immich-ml.nix` bouwt de unit van upstream na
  (`ExecStart = unstable.immich.machine-learning`, dezelfde environment-variabelen) met
  `DynamicUser` en `CacheDirectory`. De module aanzetten zou ook immich-server, PostgreSQL en redis
  op lobos meebrengen.
- **Zelfde versie als de server.** Pakket uit `unstable`, net als op malandro; ML en server moeten
  bij elkaar passen.
- **Luisteren op alle adressen, afschermen met Nebula.** Binden op `10.77.0.2` faalt als de
  Nebula-tun nog niet bestaat. De host-firewall van lobos houdt 3003 dicht op wifi/LAN; alleen de
  vertrouwde Nebula-interface laat verkeer door, en de Nebula-firewall staat 3003 alleen toe voor
  het certificaat `malandro`.
- **Via Nebula, niet het LAN.** Werkt ook als lobos onderweg is, en het adres is vast.
- **Lage prioriteit.** `Nice=15`, `IOSchedulingClass=idle`, `CPUWeight=20`: ML-batches na een grote
  upload mogen de laptop niet traag maken (zelfde lijn als `throttle-nix-builds`).
- **Geen automatische job-herstart.** Daarvoor is een admin-API-sleutel als secret nodig; eerst
  zien hoe vaak het nodig is. Vervolg-bean.

## Risks

- Lobos vaak uit → embeddings/gezichten lopen achter tot "Ontbrekende" wordt gedraaid.
- Eerste ML-aanvraag downloadt modellen (CLIP ViT-B-32 + buffalo_l, samen ±600 MB) van Hugging Face.
