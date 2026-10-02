# Proposal

## Why

Op GNOME kon lobos met Super+P kiezen hoe een extern scherm gebruikt wordt. Onder Hyprland ontbreekt
zo'n keuze: elk extern scherm komt altijd als uitgebreid bureaublad naast de laptop (`monitor =
EXT,preferred,auto,1`). Klonen (presenteren), alleen extern (laptop dicht of opzij) of alleen laptop
kan nu alleen met handwerk via `hyprctl`.

## What Changes

- Nieuwe toets **SUPER+SHIFT+P** opent een fuzzel-menu met vier standen: **Uitgebreid**, **Klonen**,
  **Alleen extern**, **Alleen laptop**. De keuze wordt direct toegepast met `hyprctl keyword monitor`.
- Werkt met elk extern scherm (HDMI, USB-C/DP, DisplayLink `DVI-I-1`): "extern" = de eerste output
  die niet `eDP-1` is, ook als die uitgeschakeld staat.
- Zonder extern scherm verschijnt alleen een korte melding en verandert er niets.
- **Vangnet:** wordt het externe scherm losgekoppeld terwijl de laptop uit staat ("Alleen extern"),
  dan gaat `eDP-1` automatisch weer aan. Anders blijft het laptopscherm zwart en is het menu
  onbereikbaar.
- Niet onthouden: na een Hyprland-reload, herstart of nieuw aansluiten geldt weer gewoon Uitgebreid.
- Bewust niet: automatische profielen (kanshi/shikane), een revert-timer bij "Alleen extern",
  lid-switch-gedrag.

## Capabilities

### New Capabilities
- `display-mode-menu`: het kiezen van de schermstand (uitgebreid, klonen, alleen extern, alleen laptop)
  op lobos via SUPER+SHIFT+P, plus het herstel van het laptopscherm bij loskoppelen.

### Modified Capabilities
<!-- geen: de workspace-binding (workspace-monitor-binding) verandert niet van gedrag -->

## Impact

- `home/hyprland/`: nieuw script (menu + toepassen), binding SUPER+SHIFT+P plus regel in de
  hulptekst in `bindings.nix`.
- `home/hyprland/wayle.nix`: de bestaande event-listener (`hyprland-workspace-binder`) krijgt het
  vangnet "eDP-1 aan bij `monitorremoved`" erbij, en moet "geen eDP-1 actief" aankunnen.
- Afhankelijk van: fuzzel, libnotify, jq (allemaal al in gebruik).
- Alleen home-manager; geen `nixos-rebuild` nodig.
