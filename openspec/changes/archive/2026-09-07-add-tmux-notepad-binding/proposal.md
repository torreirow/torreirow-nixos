## Why

De notepad-werkomgeving (vim met `LinnyStart`, een `watch git-sync` en een hugo-server op
poort 1314) is als smug-layout `notepad.yml` beschikbaar, maar moet nu handmatig met
`smug start notepad` in een shell worden gestart. Er is geen snelle manier om er vanuit tmux
naartoe te springen, terwijl er wél al zo'n launcher bestaat voor de `spg`/cockpit-layout.

## What Changes

- Nieuwe tmux key-binding `bind N` (prefix + `N`) in `home/tmux.nix`
  (`programs.tmux.extraConfig`) die de smug `notepad`-layout opent.
- Gedrag is **idempotent**: bestaat de tmux-sessie al, dan wordt er alleen naartoe geswitcht;
  bestaat hij niet, dan wordt `smug start notepad --detach` uitgevoerd en daarna geswitcht.
- In tegenstelling tot de bestaande `C-c`/spg-binding gebruikt deze **`switch-client`** in
  plaats van een popup met `attach`, omdat notepad een volwaardige, blijvende werkomgeving is
  (geen wegklikbare overlay).

## Capabilities

### New Capabilities
- `tmux-notepad-binding`: Een tmux prefix-keybinding die de smug notepad-layout idempotent
  start en er via `switch-client` naartoe springt.

### Modified Capabilities
<!-- Geen bestaande capability-requirements wijzigen. -->

## Impact

- **Gewijzigd bestand**: `home/tmux.nix` (regel-toevoeging in `programs.tmux.extraConfig`).
- **Afhankelijkheden**: `smug` en de bestaande smug-config `home/dotfiles/.config/smug/notepad.yml`
  (sessienaam `TorrLinny`). Geen nieuwe packages.
- **Toets `N`** is nog vrij; bezet zijn `T`, `J`, `B`, `C-c`, `g`, `r`.
- Activeren via `home-manager switch`; geen impact op andere hosts of services.
