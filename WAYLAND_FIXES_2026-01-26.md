# Wayland Window Positioning Fixes - 26 januari 2026

## Probleem
Bitwarden app (en mogelijk andere Electron apps) draaien wel maar tonen geen window. Window is niet zichtbaar in alt-tab. Dit is een bekend probleem in GNOME Shell 49.2 met Wayland en Electron apps.

## Diagnose
- Systeem: NixOS 25.11, GNOME Shell 49.2, Wayland
- Bitwarden proces draait wel (process ID gevonden)
- Geen window detecteerbaar met xdotool
- Actieve extensies verschillen van configuratie (gnome.nix was uitgecommentarieerd in configuration.nix:17)
- Handmatig geïnstalleerde extensies: launcher, emoji-copy, dash-to-panel, appindicator, search-light, clipboard-history, mediacontrols

## Toegepaste oplossingen

### 1. Electron Wayland fix in system configuratie
**Bestand:** `hosts/lobos/configuration.nix`
**Regel:** 452
**Wijziging:**
```nix
environment.variables = {
  CHROME_FLAGS = "--disable-gpu --disable-software-rasterizer";
  # Electron apps (Bitwarden, VSCode, etc.) Wayland fix for GNOME 49+
  ELECTRON_OZONE_PLATFORM_HINT = "wayland";
};
```

**Wat dit doet:** Forceert Electron apps om native Wayland te gebruiken in plaats van XWayland. Dit lost window positioning problemen op in GNOME 49+.

**Beïnvloedt:** Alle Electron-based apps:
- bitwarden-desktop
- vscode
- signal-desktop
- slack
- teams-for-linux
- zapzap
- En andere Electron apps

### 2. GNOME Mutter experimental features via home-manager
**Nieuw bestand:** `home/gnome-desktop/wayland-fixes.nix`
```nix
{ lib, ... }:

{
  # GNOME 49+ Wayland window positioning fixes
  dconf.settings = {
    "org/gnome/mutter" = {
      # Experimental features voor betere window handling in GNOME 49+
      experimental-features = [ "scale-monitor-framebuffer" ];

      # Center new windows (helpt met positioning issues)
      center-new-windows = true;
    };
  };
}
```

**Bestand gewijzigd:** `home/gnome-desktop/default.nix`
**Regel:** 8
```nix
imports = [
  ./desktop-shortcuts.nix
  ./wayland-fixes.nix  # <-- TOEGEVOEGD
];
```

**Wat dit doet:**
- `scale-monitor-framebuffer`: Experimental feature die betere window positioning geeft in GNOME 49+
- `center-new-windows`: Zorgt dat nieuwe windows gecentreerd worden (helpt met positioning)

## Toepassen van de fixes

### Stap 1: System rebuild
```bash
cd /home/wtoorren/data/git/torreirow/torreirow-nixos
sudo nixos-rebuild switch --flake .#lobos
```

### Stap 2: Home-manager rebuild
```bash
home-manager switch --flake .#wtoorren@lobos
```

### Stap 3: GNOME herstarten
Optie A: Uitloggen en weer inloggen
Optie B: GNOME Shell herstarten: Alt+F2, typ `r`, druk Enter

### Stap 4: Bitwarden testen
```bash
# Sluit huidige instantie
pkill bitwarden

# Start opnieuw
bitwarden-desktop
```

## Verificatie commando's

```bash
# Check of ELECTRON_OZONE_PLATFORM_HINT is gezet
echo $ELECTRON_OZONE_PLATFORM_HINT

# Check mutter experimental features
gsettings get org.gnome.mutter experimental-features

# Check center-new-windows
gsettings get org.gnome.mutter center-new-windows

# Zoek naar Bitwarden window
xdotool search --class bitwarden

# Check of Bitwarden proces draait
ps aux | grep bitwarden | grep -v grep
```

## Verwachte resultaten na fixes
- Bitwarden window verschijnt normaal
- Window is zichtbaar in alt-tab
- Show/hide functie van Bitwarden werkt
- Andere Electron apps (VSCode, Signal, etc.) tonen ook hun windows correct
- Algemene verbetering in window positioning in GNOME 49.2

## Rollback indien nodig

### Systeem rollback:
```bash
# List previous generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Home-manager rollback:
```bash
# List previous generations
home-manager generations

# Switch to specific generation (vervang XX met nummer)
/nix/store/...-home-manager-generation-XX/activate
```

### Handmatige undo:
1. Verwijder `ELECTRON_OZONE_PLATFORM_HINT` uit `hosts/lobos/configuration.nix:452`
2. Verwijder `./wayland-fixes.nix` uit `home/gnome-desktop/default.nix:8`
3. Verwijder bestand `home/gnome-desktop/wayland-fixes.nix`
4. Rebuild beide configuraties

## Relevante informatie voor debugging

### Systeem info bij tijd van fix:
- Hostname: lobos
- GNOME Shell versie: 49.2
- Session type: wayland
- NixOS versie: 25.11
- Branch: main
- Git hash laatste commit: 395ddf6

### Geïnstalleerde packages (relevant):
- bitwarden-desktop (via nixpkgs, regel 55 in hosts/lobos/programs.nix)
- vscode
- signal-desktop
- slack
- teams-for-linux
- zapzap
- super-productivity

### Extensies actief tijdens probleem:
- launcher@hedgie.tech
- emoji-copy@felipeftn
- dash-to-panel@jderose9.github.com
- appindicatorsupport@rgcjonas.gmail.com
- search-light@icedman.github.com
- clipboard-history@alexsaveau.dev
- mediacontrols@cliffniff.github.com

## Aanvullende opmerkingen
- Het bestand `hosts/lobos/gnome.nix` staat uitgecommentarieerd in configuration.nix:17
- De extensies in gnome.nix komen niet overeen met daadwerkelijk actieve extensies
- Dash-to-panel configuratie staat in `home/gnome-desktop/desktop-shortcuts.nix`
- Er zijn ook Chrome crash fixes actief (CHROME_FLAGS)

## Bronnen en referenties
- GNOME 47+ heeft bekende window positioning issues met Wayland
- Electron apps hebben specifieke Wayland compatibiliteits problemen
- `ELECTRON_OZONE_PLATFORM_HINT` is de officiële Electron variabele voor Wayland backend selectie
- Mutter experimental features zijn gedocumenteerd in GNOME development notes
