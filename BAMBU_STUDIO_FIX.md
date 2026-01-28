# Bambu Studio Window Problem - Root Cause Analysis

## Problem
Bambu Studio niet toont geen venster sinds 26 januari 2026. App start wel maar windows hebben width=0.

## Root Cause
1. **GNOME Mutter experimental feature**: `scale-monitor-framebuffer` werd toegevoegd in commit 615209a op 26 jan
2. **wxWidgets incompatibiliteit**: Bambu Studio gebruikt wxWidgets die niet compatible is met deze Mutter feature
3. **Multi-monitor setup**: Probleem verergert met 2 monitors (eDP-1 1920x1200 + HDMI-1 1920x1080)

## Diagnostic Output
```
(bambu-studio:2): Gtk-CRITICAL **: gtk_window_resize: assertion 'width > 0' failed
```

## Solution Applied
1. Verwijderd `home/gnome-desktop/wayland-fixes.nix`
2. Uitgecommentarieerd import in `home/gnome-desktop/default.nix`  
3. Disabled via gsettings: `gsettings set org.gnome.mutter experimental-features "[]"`
4. Bambu Studio via flatpak: `flatpak install flathub com.bambulab.BambuStudio`
5. Verwijderd bambu-studio NixOS package (AppImage had webkitgtk dependency problemen)

## Status
- NixOS bambu-studio package: VERWIJDERD (webkitgtk incompatibiliteit)
- Flatpak bambu-studio: GEÏNSTALLEERD (maar nog steeds venster probleem)
- scale-monitor-framebuffer: UITGESCHAKELD

## Outstanding Issue
Zelfs na het uitschakelen van scale-monitor-framebuffer blijft bambu-studio geen venster tonen.
Mogelijk is er een dieper probleem met wxWidgets + GNOME 49.2 + multi-monitor Wayland setup.

## Workaround Options
1. Gebruik bambu-studio op een andere machine
2. Downgrade GNOME naar een eerdere versie
3. Schakel tijdelijk naar X11 sessie i.p.v. Wayland
4. Wacht op wxWidgets of Bambu Studio update die GNOME 49+ ondersteunt

## Files Changed
- `overlays/default.nix`: bambu-studio overlay verwijderd/gedocumenteerd
- `hosts/lobos/programs.nix`: bambu-studio package uitgecommentarieerd  
- `hosts/lobos/configuration.nix`: xdg-portal fixes (wlr -> gnome)
- `hosts/lobos/gnome.nix`: gpaste fix
- `home/gnome-desktop/default.nix`: wayland-fixes.nix import uitgecommentarieerd
- `home/gnome-desktop/wayland-fixes.nix`: VERWIJDERD

## Date
28 januari 2026
