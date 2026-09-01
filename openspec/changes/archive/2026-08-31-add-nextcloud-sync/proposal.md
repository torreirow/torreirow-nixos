## Why

Er is geen home-manager-manier om per user een Nextcloud-sync in te regelen op de
desktop (lobos). De GUI-client vereist een grafische sessie en een tray, en levert
geen declaratieve, herbruikbare configuratie op. Gewenst is een headless sync die
"gewoon werkt" op een timer, zonder een wachtwoord in de wereld-leesbare nix-store of
in git te lekken.

Referentie: https://wiki.nixos.org/wiki/Nextcloud#Nextcloudcmd (Beans-epic `nixos-3es6`).

## What Changes

- Nieuwe home-manager module `home/module/nextcloud-sync/` (`services.nextcloud-sync`),
  geïmporteerd in `homeConfigurations."wtoorren@linuxdesktop"` in `flake.nix`.
- Per sync-paar (`syncs.<naam>`) wordt een oneshot `systemd.user.service` +
  `systemd.user.timer` gegenereerd die `nextcloudcmd` draait.
- Authenticatie via `nextcloudcmd --non-interactive`, dat `$NC_USER`/`$NC_PASSWORD`
  uit de environment leest. Die komen uit een **handmatig** aangemaakt
  EnvironmentFile (`~/.config/nextcloud-sync/credentials`, mode 0600) — bewust niet
  door Nix beheerd, dus nooit in de nix-store of git.
- Timer-cadans via `OnUnitActiveSec` (interval ná de vorige run, geen overlap),
  default 10 min; eerste run 2 min na login (`OnActiveSec`).
- `pkgs.nextcloud-client` (levert `nextcloudcmd`) wordt via de module toegevoegd aan
  de home-packages wanneer de module enabled is.

### Spike-uitkomst (bepalend voor het ontwerp)

`nextcloudcmd -n` (netrc) leest **hardcoded `~/.netrc`** — geen flag voor een custom
pad. Daarom is de netrc-route vervangen door `--non-interactive` +
`EnvironmentFile=`, wat het credential wél in `~/.config/` laat staan zoals gewenst.

## Capabilities

### New Capabilities

- `nextcloud-sync`: een herbruikbare home-manager module die per user en per sync-paar
  een headless, getimede Nextcloud-sync inregelt met `nextcloudcmd`, met credentials
  uit een handmatig EnvironmentFile (nooit in de nix-store).

## Impact

- `home/module/nextcloud-sync/default.nix` — nieuw (module)
- `home/module/nextcloud-sync/README.md` — nieuw (docs)
- `flake.nix` — module-import toegevoegd aan `wtoorren@linuxdesktop`
- Geen live impact bij `enable = false` (default): de module voegt dan niets toe.
  Activeren vereist eenmalig een handmatig credentials-bestand + `enable = true`.
- Geen agenix/homeage-afhankelijkheid; geen NixOS-laag nodig.
