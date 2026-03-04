# Claude Code Werkdocument - torreirow-nixos

**Laatst bijgewerkt:** 2026-03-04 13:24

## Samenvatting Huidige Situatie

**Probleem:** Hyprland crasht bij login met `GLIBCXX_3.4.34 not found` error

**Root Cause:** Hyprland flake (0.54.0) is gebouwd met gcc-15, maar de binary's RPATH verwijst naar gcc-14 libraries. De dynamic linker laadt libraries op basis van RPATH (niet LD_LIBRARY_PATH), dus gebruikt gcc-14 die GLIBCXX_3.4.34 mist.

**Pogingen:**
1. ❌ Expliciet package instellen - wrapper heeft geen LD_LIBRARY_PATH
2. ❌ symlinkJoin wrapper - verliest `.override` attribute
3. ❌ environment.sessionVariables - werkt niet bij display manager login
4. ✅ **overrideAttrs + patchelf** - patcht RPATH permanent, behoudt `.override`

**Volgende Stap:** `sudo nixos-rebuild switch --flake .#lobos` uitvoeren en Hyprland testen.

---

## Huidige Status

### Sessie 2026-03-04 (middag) - Hyprland Setup & Library Conflict Fix

**Branch:** `add-hyprland`

**Probleem:** Hyprland verschijnt in login scherm maar crasht direct terug naar login

**Diagnose (iteratief):**
- Error in journalctl: `GLIBCXX_3.4.34' not found`
- Eerste poging: Hyprland was dubbel geïnstalleerd (system + home-manager)
  - `package = null` in home-manager loste dit niet op
  - System versie had óók library mismatch
- Tweede diagnose: NixOS Hyprland 0.52.1 gebouwd met gcc-15 maar runtime gebruikt gcc-14.3.0-lib
  - gcc-14 heeft alleen GLIBCXX_3.4.26
  - Hyprland heeft GLIBCXX_3.4.34 nodig (alleen in gcc-15)
- **Diepere diagnose (na flake module toevoegen):**
  - Hyprland flake 0.54.0 werd WEL geïnstalleerd
  - MAAR: `libhyprutils.so.10` (dependency) is gebouwd MET gcc-15.2.0-lib
  - Runtime linkt deze library aan gcc-14.3.0-lib (system default)
  - Error: `/nix/store/...-gcc-14.3.0-lib/lib/libstdc++.so.6: version 'GLIBCXX_3.4.34' not found (required by libhyprutils.so.10)`

**Oplossingen (iteratief):**

1. **Eerste poging:** Hyprland flake package expliciet instellen
   - Hyprland flake toegevoegd aan `flake.nix` inputs
   - Flake module (`hyprland.nixosModules.default`) voor NixOS integratie
   - Expliciet `programs.hyprland.package = hyprland-pkg;` ingesteld
   - **Resultaat:** Package heeft gcc-15 dependencies, maar wrapper stelt geen LD_LIBRARY_PATH in
   - Dynamic linker gebruikt system default (gcc-14) in plaats van package dependencies

2. **Tweede poging:** Custom wrapper met LD_LIBRARY_PATH
   - `symlinkJoin` gebruikt om Hyprland package te wrappen
   - `makeWrapper` om Hyprland binary te wrappen met `--prefix LD_LIBRARY_PATH`
   - **Resultaat:** Error `attribute 'override' missing` - Hyprland NixOS module verwacht `.override` functie
   - `symlinkJoin` maakt een nieuwe derivation zonder `.override` attribute

3. **Derde poging:** LD_LIBRARY_PATH via environment.sessionVariables
   - Eenvoudiger: gebruik flake package direct zonder wrapper
   - Set `environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib"`
   - **Resultaat:** Rebuild succesvol (13:23), maar probleem niet opgelost
   - sessionVariables werken alleen binnen actieve sessie, niet bij login via display manager
   - ldd toont nog steeds gcc-14 libraries (RPATH is hardcoded in binary)

4. **Definitieve oplossing:** overrideAttrs + patchelf om RPATH te wijzigen
   - Gebruik `hyprland-pkg.overrideAttrs` om `.override` attribute te behouden
   - `patchelf --set-rpath` om gcc-15 lib pad toe te voegen aan RPATH
   - Patches zowel `Hyprland` als `.Hyprland-wrapped` binaries
   - RPATH wijziging is permanent in de binary (niet afhankelijk van environment)

**Aangepaste bestanden:**
- `flake.nix` - hyprland input, nixosModule EN `hyprland-pkg` argument toegevoegd
- `flake.lock` - hyprland en dependencies toegevoegd
- `hosts/lobos/hyprland.nix` - overrideAttrs + patchelf RPATH fix, xdg-desktop-portal-hyprland verwijderd
  ```nix
  hyprland-fixed = hyprland-pkg.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      # Add gcc-15 libraries to RPATH
      for binary in $out/bin/Hyprland $out/bin/.Hyprland-wrapped; do
        if [ -f "$binary" ] && [ ! -L "$binary" ]; then
          ${pkgs.patchelf}/bin/patchelf \
            --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib:$(${pkgs.patchelf}/bin/patchelf --print-rpath $binary)" \
            $binary || true
        fi
      done
    '';
  });

  programs.hyprland = {
    enable = true;
    package = hyprland-fixed;  # Patched with gcc-15 in RPATH
    xwayland.enable = true;
  };
  ```
- `home/hyprland-desktop/hyprland.nix` - behoudt `package = null`

**Status:**
- ✅ Library conflict geïdentificeerd (gcc-14 vs gcc-15 mismatch)
- ✅ Root cause gevonden (libhyprutils.so.10 runtime library mismatch)
- ✅ Hyprland flake geïntegreerd in configuratie
- ✅ Expliciet package instelling toegevoegd (werkte niet - geen LD_LIBRARY_PATH)
- ✅ nixos-rebuild uitgevoerd (3x: 13:00, 13:02, 13:08) - probleem bleef bestaan
- ✅ Diepere analyse: wrapper stelt geen LD_LIBRARY_PATH in
- ✅ Custom wrapper gemaakt met symlinkJoin + makeWrapper (13:13)
- ❌ nixos-rebuild gefaald (13:15) - `attribute 'override' missing` error
- ✅ Nieuwe oplossing: LD_LIBRARY_PATH via environment.sessionVariables (13:16)
- ✅ nixos-rebuild succesvol (13:23)
- ❌ Probleem blijft: sessionVariables werkt niet bij login, ldd toont nog gcc-14
- ✅ Definitieve oplossing: overrideAttrs + patchelf om RPATH te patchen (13:24)
- ⏳ **WACHT OP:** `sudo nixos-rebuild switch --flake .#lobos` (met patchelf RPATH fix)
- ⏳ **DAARNA:** Uitloggen, Hyprland selecteren in login scherm, inloggen

**Quick Actions:**
```bash
# 1. Rebuild systeem met LD_LIBRARY_PATH sessionVariable
sudo nixos-rebuild switch --flake .#lobos

# 2. Check Hyprland binary libraries (na rebuild)
ldd /run/current-system/sw/bin/.Hyprland-wrapped 2>&1 | grep libstdc

# 3. Verwachte output (als het werkt):
# libstdc++.so.6 => /nix/store/...-gcc-15.2.0-lib/lib/libstdc++.so.6

# 4. Uitloggen en Hyprland selecteren in login scherm

# 5. Na login in Hyprland: check environment en test keybindings
echo $LD_LIBRARY_PATH  # Zou gcc-15 path moeten bevatten
# Super+Return = Terminal
# Super+D = App launcher
# Super+M = Exit Hyprland
```

**Configuratie:**
- System: `hosts/lobos/hyprland.nix` - Hyprland installatie + system packages
- System: `hosts/lobos/gnome.nix` - LightDM display manager (voor beide desktops)
- Home-manager: `home/hyprland-desktop/` - Volledige Hyprland configuratie (waybar, wofi, mako, keybindings)

**Test na login:**
```bash
# Check versie
which Hyprland  # moet /run/current-system/sw/bin/Hyprland zijn

# Basis keybindings
# Super+Return = Terminal (kitty)
# Super+D = App launcher (wofi)
# Super+Q = Venster sluiten
# Super+M = Exit Hyprland
```

**Git:**
- Branch: `add-hyprland`
- Modified: `flake.nix`, `flake.lock`, `hosts/lobos/gnome.nix`, `hosts/lobos/hyprland.nix`, `home/hyprland-desktop/hyprland.nix`, `CLAUDE.md`
- Uncommitted changes (wacht op succesvolle test na nixos-rebuild)

**Technische Details:**

Het probleem was dat:
1. Hyprland flake package is gebouwd met gcc-15 (heeft GLIBCXX_3.4.34)
2. Package dependencies verwijzen correct naar gcc-15.2.0-lib
3. **MAAR:** Dynamic linker (ld.so) gebruikt system default library path
4. NixOS 25.11 heeft gcc-14.3.0-lib in system path (alleen GLIBCXX_3.4.26)
5. Runtime linking gebruikt gcc-14 in plaats van gcc-15 → error

Poging 1 - symlinkJoin wrapper: GEFAALD
- `symlinkJoin` + `makeWrapper` om binary te wrappen
- Error: `attribute 'override' missing`
- Hyprland NixOS module (lib.nix:10) verwacht `pkg.override` functie
- `symlinkJoin` maakt nieuwe derivation zonder `.override` attribute

Poging 2 - sessionVariables: BUILD SUCCESVOL, RUNTIME GEFAALD
- `environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib"`
- Rebuild succesvol, geen build errors
- MAAR: sessionVariables worden alleen geladen binnen actieve sessie
- Display manager (LightDM/GDM) laadt deze niet bij login
- ldd toont nog gcc-14 - RPATH in binary is hardcoded

Poging 3 - overrideAttrs + patchelf: DEFINITIEVE OPLOSSING
- `hyprland-pkg.overrideAttrs` behoudt alle derivation attributes (inclusief `.override`)
- `patchelf --set-rpath` patcht de binary's RPATH permanent
- Voegt `${pkgs.stdenv.cc.cc.lib}/lib` toe AAN HET BEGIN van RPATH
- Dynamic linker zoekt in RPATH volgorde: gcc-15 komt eerst
- Patches zowel wrapper als wrapped binary (`|| true` voor symlinks)

**Debug Commands (gebruikt voor diagnose):**
```bash
# Check welke libstdc++ Hyprland probeert te laden (toont RPATH, niet runtime LD_LIBRARY_PATH!)
ldd /nix/store/.../bin/.Hyprland-wrapped 2>&1 | grep -E "(libstdc|GLIBCXX|not found)"

# Check RPATH van binary (dit is wat ldd gebruikt)
patchelf --print-rpath /nix/store/.../bin/.Hyprland-wrapped

# Check welke gcc versie een library verwacht
nix-store -q --references /nix/store/...-hyprutils-... | grep gcc

# Check dependency tree
nix-store -q --tree /nix/store/...-hyprland-... | grep -E "gcc|hyprutils"

# Check beschikbare GLIBCXX versies in gcc-14
strings /nix/store/...-gcc-14.3.0-lib/lib/libstdc++.so.6 | grep "GLIBCXX_3.4"

# Check beschikbare GLIBCXX versies in gcc-15
strings /nix/store/...-gcc-15.2.0-lib/lib/libstdc++.so.6 | grep "GLIBCXX_3.4" | tail -5
```

**Belangrijke lessen:**
- `ldd` gebruikt de RPATH van de binary, NIET runtime environment variabelen
- `environment.sessionVariables` werkt alleen binnen een sessie, niet bij login via display manager
- `symlinkJoin` maakt een nieuwe derivation die `.override` verliest
- `overrideAttrs` behoudt alle derivation attributes voor compatibility met NixOS modules
- `patchelf --set-rpath` is de juiste manier om library paths permanent te wijzigen

---

## Eerdere Sessies (OPGELOST)

### Sessie 2026-03-04 (ochtend) - Wayland Best Practices & App Compatibility Fix

**Branch:** `wayland-best-practices` (COMPLETED)

**Probleem:** Veel apps werken niet (OnlyOffice, SubtitleEdit, Zoom, etc.)

**Oplossing:** Pragmatische Wayland fallbacks geïmplementeerd

**Status:** ✅ OPGELOST - Branch kan gemerged worden indien gewenst

---

## Oude Sessies (ARCHIEF)

### Sessie 2026-02-24 (middag) - OPGELOST

**Probleem:** Qt apps (Clementine, MuseScore) gaven geen venster op GNOME 49.2 Wayland.

**Diagnose:**
- Qt5 warning: `Warning: Ignoring XDG_SESSION_TYPE=wayland on Gnome. Use QT_QPA_PLATFORM=wayland to run on Wayland anyway.`
- Zonder expliciete `QT_QPA_PLATFORM` setting faalt Qt silently en verschijnt geen venster
- `QT_QPA_PLATFORM=xcb` werkte NIET (werd genegeerd)
- `QT_QPA_PLATFORM=wayland` werkt WEL

**Oplossing (toegepast):**
Alle GNOME/Wayland settings zijn nu geconsolideerd in `hosts/lobos/gnome-wayland.nix`:

```nix
# Mutter experimental features
services.desktopManager.gnome.extraGSettingsOverrides = ''
  [org/gnome/mutter]
  experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
  center-new-windows=true
'';

# Qt apps (Clementine, mscore, etc.)
environment.sessionVariables = {
  QT_QPA_PLATFORM = "wayland";
};

# Electron apps (Bitwarden, VSCode, Signal, etc.)
environment.variables = {
  ELECTRON_OZONE_PLATFORM_HINT = "wayland";
};
```

**Status:**
- [x] Nieuwe `hosts/lobos/gnome-wayland.nix` aangemaakt met alle GNOME/Wayland settings
- [x] Oude `hosts/lobos/gnome.nix` verwijderd
- [x] Duplicaten uit `hosts/lobos/configuration.nix` verwijderd
- [x] `sudo nixos-rebuild switch --flake .#lobos` succesvol uitgevoerd
- [x] Clementine werkt met `QT_QPA_PLATFORM=wayland`
- [x] NixOS MuseScore (`mscore` 4.4.3) werkt met `QT_QPA_PLATFORM=wayland`
- [x] Uitloggen en opnieuw inloggen (om sessionVariables permanent te laden)
- [x] Test apps zonder environment variable prefix

### MuseScore: Flatpak vs NixOS

| Versie | Platform | Status |
|--------|----------|--------|
| Flatpak 4.6.3 | Hardcodes xcb | **WERKT NIET** - negeert `QT_QPA_PLATFORM` |
| NixOS 4.4.3 (`mscore`) | Respecteert env var | **WERKT** met `QT_QPA_PLATFORM=wayland` |

**Aanbeveling:** Gebruik de NixOS versie (`mscore`) in plaats van Flatpak.

### Refactoring configuratie

De GNOME/Wayland configuratie is gerefactored:

**Voorheen:** Settings verspreid over `configuration.nix` en niet-actieve `gnome.nix`

**Nu:** Alles geconsolideerd in `gnome-wayland.nix`:
- GNOME desktop services (gdm, gnome-settings-daemon)
- Mutter experimental features
- XDG portals
- Wayland environment variables (Qt + Electron)
- GNOME extensions en packages

### Git Status
- **Branch:** main (gesynchroniseerd met origin)
- **Laatste commit:** `2c85dce fix flatpak and x11-on-wayland apps`
- **Backup branch:** `backup-before-reset-2026-02-24` (oude staat voor reset)

## Te doen

Alle taken zijn afgerond.

## Configuratie bestanden

### hosts/lobos/gnome-wayland.nix (NIEUW)

Bevat alle GNOME/Mutter/Wayland settings:
- `services.xserver.enable`
- `services.displayManager.gdm.enable`
- `services.desktopManager.gnome.enable`
- `services.desktopManager.gnome.extraGSettingsOverrides` (Mutter features)
- `xdg.portal` configuratie
- `environment.sessionVariables.QT_QPA_PLATFORM`
- `environment.variables.ELECTRON_OZONE_PLATFORM_HINT`
- GNOME extensions packages

### hosts/lobos/configuration.nix

Opgeschoond - GNOME settings verwijderd, verwijst nu naar `gnome-wayland.nix` via import.

## Handmatig testen (voor uitloggen)

```bash
# Test Clementine met wayland
QT_QPA_PLATFORM=wayland clementine

# Test NixOS MuseScore (WERKT)
QT_QPA_PLATFORM=wayland mscore

# Test Flatpak MuseScore (WERKT NIET - hardcodes xcb)
flatpak run org.musescore.MuseScore
```

## Na uitloggen/inloggen

```bash
# Apps zouden nu moeten werken zonder prefix
clementine
mscore

# Check environment
echo $QT_QPA_PLATFORM  # zou "wayland" moeten tonen
```

## Herstel instructies

Als Qt apps nog steeds niet werken na de fix:
```bash
# Probeer xcb fallback
QT_QPA_PLATFORM=xcb clementine

# Of verwijder de setting en laat Qt zelf kiezen
# (comment out QT_QPA_PLATFORM in gnome-wayland.nix)
```

Terug naar backup git staat:
```bash
git reset --hard backup-before-reset-2026-02-24
```

## Systeem Informatie

### Lobos (Desktop)
- **OS:** NixOS 25.11
- **Desktop Environments:**
  - GNOME 49.2 (Wayland) - primair
  - Hyprland (Wayland) - in setup
- **Display Manager:** LightDM (voor multi-desktop selectie)
- **Mutter:** 49.2

### Malandro (Server)
- **OS:** NixOS 25.11
- **Services:** Nginx, Home Assistant, Grafana, Paperless, Vaultwarden, Gitea, etc.

## Useful Commands

```bash
# NixOS rebuild
sudo nixos-rebuild switch --flake .#lobos

# Home-manager rebuild
home-manager switch --flake .#wtoorren@linuxdesktop --extra-experimental-features nix-command -b backup-$(date +%s) --impure

# Hyprland debug
journalctl -b -0 --no-pager | grep -i hyprland  # Check logs
which -a Hyprland  # Check welke versie wordt gebruikt
hyprctl version  # Check Hyprland versie (alleen binnen Hyprland sessie)
ldd /run/current-system/sw/bin/.Hyprland-wrapped 2>&1 | grep libstdc  # Check library dependencies
nix-store -q --references $(readlink -f /run/current-system/sw/bin/Hyprland) | grep gcc  # Check gcc versie

# Test Qt app met specifiek platform
QT_QPA_PLATFORM=wayland clementine
QT_QPA_PLATFORM=wayland mscore

# Check huidige environment
echo $QT_QPA_PLATFORM

# Git
git status
git diff --staged
git log --oneline -10

# Flatpak beheer
flatpak list --app
flatpak uninstall org.musescore.MuseScore
```