## Metingen (malandro, 2026-11-05, Immich 3.3.5-commando, doel 720p H.264)

| Bron                     | CPU   | VAAPI hw-decode | VAAPI sw-decode |
|--------------------------|-------|-----------------|-----------------|
| 1080p H.264 High, 3 s    | 4,4 s | 1,3 s           | 3,4 s           |
| 4K HEVC 10-bit, 2 s      | 8,7 s | 2,1 s           | 9,9 s           |
| 640x360 H.264/mpeg4      | -     | ok / n.v.t.     | faalt zonder patch, ok met |

Drivers getest: iHD 26.1.6 (26.05), iHD 26.3.5 (unstable), i965 2.4.1. Alle drie gelijk. Gekozen:
iHD uit de stabiele pkgs.

## Decisions

- **Patch i.p.v. instellingen.** Geen Immich-instelling zet `format=nv12`; `targetResolution`
  aanpassen helpt niet voor kleine bronnen.
- **Kopie + één bestand vervangen.** Node lost ESM-imports op via het echte pad, dus een
  symlink-boom met één vervangen bestand laadt de rest uit het oude pad (en het oude
  `media.js` via relatieve imports). Daarom een volledige kopie (±420 MB) waarin alle
  verwijzingen naar het oude store-pad worden omgezet. Herbouwen vanaf de bron (pnpm, vite) is
  op de J3455 veel duurder.
- **accelDecode aan.** 3-4x sneller bij HEVC; voor bronnen die de GPU niet kan decoderen
  (mpeg4, H.264 Baseline in motion photos) valt Immich zelf terug op sw-decode + VAAPI-encode.
- **Vervolg upstream:** melden bij Immich (issue/PR) zodat de patch later weg kan.
