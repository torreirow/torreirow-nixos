## Context

mpenzi draait home-manager al als NixOS-module, via `modules/wtoorren-admin.nix`. Maaike heeft
geen home-manager. De gouden Nextcloud- en ZapZap-config staan al in
`home/profiles/maaike/defaults/`. `secrets/spotify-maaike.age` bestaat (commit 8240fde).

## Goals / Non-Goals

**Goals:** standaard van één app terugzetten met één commando; seeds die niets overschrijven;
Spotify-login die een deploy overleeft; dezelfde code voor seeden en herstellen.

**Non-Goals:** Plasma-instellingen beheren (geen plasma-manager); Signal-sleutels of
app-wachtwoorden in de repo; Thunderbird/Gmail-OAuth (komt later, handwerk).

## Decisions

1. **Eén seed-script voor beide routes.** `home/profiles/maaike/seeds.nix` levert de lijst
   (app → bestanden in `$HOME` → bron in de store, plus het procespatroon) en één script
   `seed-apps [--force] <app>...`. De HM-activatie draait het zonder `--force` (alleen
   ontbrekende bestanden); `herstel-app` draait het als de gebruiker met `--force` (eerst
   `*.bak-<datum>`). Zo kunnen seed en herstel niet uit elkaar lopen.
   - Kopie (`install -D -m 0600`), geen HM-symlink: de apps schrijven hun eigen config en een
     read-only store-link breekt ze.
   - De activatie loopt in `home-manager-maaike.service` (bij boot en bij elke switch). "Bij de
     eerste login" betekent dus: voordat ze voor het eerst inlogt.
2. **Bitwarden-seed is een minimale `data.json`.** Het formaat (`global_environment_environment`
   met `region: "Self-hosted"` en `urls.base`, plus `stateVersion` 83) komt uit de app.asar van
   bitwarden-desktop 2026.8.0. Met `stateVersion` erin migreert de app vanaf die versie in plaats
   van het bestand als leeg te behandelen. Een nieuwere app migreert vanzelf verder.
3. **herstel-app draait als root, het kopiëren als de gebruiker.** `pkill -u <user>` stopt de
   app (alleen haar processen, dus niet herstel-app zelf); `runuser -u <user>` met
   `HOME=<home>` doet de rest, zodat bestanden en mappen van haar blijven.
4. **Spotify via agenix met `path`**, zoals `spotifywto` op lobos. De module krijgt het bestand
   als optie `toorren.maaike.spotifyPrefs` (null = uit). mpenzi geeft het door met
   `builtins.pathExists`, zoals `modules/nebula.nix`; zonder bestand een warning. Herstellen =
   de symlink naar `${age.secretsDir}/spotify-maaike` opnieuw leggen (geen hele activatie).
   tmpfiles `d` maakt `~/.config` en `~/.config/spotify` van maaike, ook als agenix ze als root
   heeft aangemaakt.
5. **Policies in `hosts/mpenzi/apps.nix`**, waar de apps al staan. Chrome via
   `programs.chromium.extensions` (Chrome leest `/etc/opt/chrome/policies`). In Chrome geldt
   uBlock Origin Lite: de MV2-versie werkt daar niet meer.
6. **nixvim per gebruiker.** `home-manager.sharedModules` in wtoorren-admin zou nixvim ook bij
   maaike installeren; het gaat naar `users.wtoorren.imports`. De HM-generatie van wtoorren
   blijft gelijk (controle via drvPath).

## Risks / Trade-offs

- Spotify kan de symlink bij opslaan vervangen door een gewoon bestand. Dan werkt een nieuwe
  deploy van het secret niet meer tot `herstel-app maaike spotify`. Zo werkt het op lobos ook.
- De Nextcloud-seed bevat het account maar geen app-wachtwoord (dat staat in KWallet). Na herstel
  logt Maaike één keer in via de browser.
