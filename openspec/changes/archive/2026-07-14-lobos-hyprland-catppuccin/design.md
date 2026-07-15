# Design: lobos-hyprland-catppuccin

## Architectuur

```
flake.nix
  └── nixosConfigurations.lobos
        ├── hosts/lobos/configuration.nix
        │     └── imports: hyprland.nix  ← nieuw
        └── homeConfigurations."wtoorren@linuxdesktop"
              └── modules: home/hyprland/default.nix  ← nieuw

Sessie keuze bij login (GDM):
  ┌─────────────────────────────────┐
  │  Kies sessie:                   │
  │  ○ GNOME        (gnome-wayland) │
  │  ● Hyprland     (hyprland)      │
  └─────────────────────────────────┘
  Geen rebuild nodig om te wisselen.
```

## NixOS module: hosts/lobos/hyprland.nix

Systeem-level config. Alleen de compositor en XDG portals — geen user config.

```nix
{
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  # XDG portal voor Hyprland (screenshot, file dialogs, screen share)
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  environment.systemPackages = with pkgs; [
    hyprpaper
    hyprlock
    hypridle
    waybar
    rofi-wayland
    mako
    kitty
    catppuccin-hyprland
    catppuccin-gtk
    catppuccin-cursors
    wl-clipboard    # al aanwezig in gnome-wayland.nix - controleer duplicaat
    grimblast       # screenshots
  ];
}
```

## Home-manager module: home/hyprland/default.nix

Declaratieve user config via `wayland.windowManager.hyprland.settings`.

### Structuur

```
home/hyprland/
  default.nix      ← hoofdmodule, importeert de rest
  waybar.nix       ← waybar config
  hyprlock.nix     ← lock screen config
  hypridle.nix     ← idle/lock timer config
```

### Hyprland config (default.nix)

Key bindings (SUPER als modifier, zelfde patroon als GNOME):

| Binding       | Actie                        |
|---------------|------------------------------|
| SUPER+Return  | kitty terminal               |
| SUPER+D       | rofi app launcher            |
| SUPER+Q       | sluit venster                |
| SUPER+L       | hyprlock (lock screen)       |
| SUPER+1..9    | workspace wisselen           |
| SUPER+SHIFT+1 | venster naar workspace       |
| SUPER+H/J/K/L | focus wisselen (vim stijl)   |
| SUPER+F       | fullscreen                   |
| Print         | screenshot (grimblast)       |

### Catppuccin Mocha kleuren voor Hyprland borders

```nix
general = {
  "col.active_border"   = "rgba(cba6f7ff)";  # mauve
  "col.inactive_border" = "rgba(585b70ff)";  # surface2
};
```

### Waybar

Minimale top bar:
```
[workspaces]  [window title]  ...  [volume] [battery] [clock]
```

Catppuccin Mocha CSS via `catppuccin-hyprland` package of inline style.

### Hyprpaper

Wallpaper config — eén achtergrond voor beide monitors (eDP-1 en DVI-I-1 zoals bij lobos).
Wallpaper pad via `~/Pictures/wallpapers/` zodat je zelf een afbeelding kunt plaatsen.

### Hypridle + Hyprlock

- 5 minuten inactief → scherm dimmen
- 10 minuten inactief → hyprlock (lock screen)
- Bij suspend → direct hyprlock

## Switchen tussen GNOME en Hyprland

GDM toont automatisch alle beschikbare sessies. Je kiest bij het inloggen.

Wil je Hyprland als standaard:
```nix
services.displayManager.defaultSession = "hyprland";
```

Wil je GNOME als standaard (huidige situatie, ongewijzigd):
```nix
services.displayManager.defaultSession = "gnome";  # al zo geconfigureerd
```

## Integratie met bestaande lobos config

- `gnome-wayland.nix` blijft volledig ongewijzigd
- `QT_QPA_PLATFORM = "wayland"` en `ELECTRON_OZONE_PLATFORM_HINT = "wayland"` zijn al systeem-breed gezet — werken ook in Hyprland
- GNOME Keyring blijft actief — Hyprland kan er gebruik van maken via PAM
- PipeWire/audio config is al aanwezig — werkt in beide sessies
- xdg-desktop-portal-gnome en xdg-desktop-portal-hyprland kunnen naast elkaar bestaan

## Risico's en aandachtspunten

- `wl-clipboard` staat al in `gnome-wayland.nix` — niet dupliceren in `hyprland.nix`
- `xdg.portal.extraPortals` uitbreiden, niet overschrijven (list merge in NixOS)
- Waybar heeft een eigen D-Bus sessie nodig — `systemctl --user start waybar` of via `exec-once`
- Hyprland `exec-once` voor autostart: hyprpaper, waybar, hypridle, mako
- Lobos heeft twee monitoren (eDP-1 + DVI-I-1 via DisplayLink) — monitor config in hyprland.conf testen
