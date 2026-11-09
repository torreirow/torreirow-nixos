# Diun — melding bij nieuwe container-images

`modules/diun.nix` draait Diun (nixpkgs, geen container) als systemd-dienst `diun.service`.
Elke dag om 07:30 kijkt Diun voor alle draaiende Docker-containers of er een nieuwer image is
en meldt dat via Telegram (dezelfde bot en chat als Alertmanager). Diun werkt niets bij.

## Wat wordt gevolgd

- **`:latest`/`:stable`-images**: melding zodra de digest van die tag verandert.
- **Gepinde tags**: een vaste tag verandert nooit, dus daar is een label nodig dat de hele repo
  volgt. Nu alleen voor vaultwarden (`diun.watch_repo`, semver-tags `x.y.z`). Voeg hetzelfde
  label toe voor andere gepinde images (ownsteps, blocky-ui, mariadb) als je die wilt volgen.
- **Eigen builds** (baikal, erugo, invoiceplane, it-tools, markmysteps-*): uitgezet met
  `diun.enable=false`; bij een registry valt daar niets te ontdekken.

Labels staan in `modules/diun.nix` zelf, niet in de modules van de containers. Een gewijzigd
label laat de container bij de deploy opnieuw starten.

## Valkuilen (Diun 4.31.0)

- Het tokenbestand van Alertmanager eindigt op een regeleinde; Diun haalt dat er niet af
  (`invalid control character in URL`). De wrapper schrijft een schone kopie naar `/run/diun`.
- `DIUN_NOTIF_TELEGRAM_CHATIDS` wordt genegeerd (`no chat IDs provided`). Gebruik
  `CHATIDSFILE` met een JSON-lijst: `["123456789"]`.

## Commando's

```bash
journalctl -u diun -f                 # laatste controle bekijken
diun notif test                       # testmelding (dienst moet draaien)
diun image list                       # wat Diun kent
```
