# Hyprland Desktop Environment - torreirow-nixos

**Status:** ACTIEF (2026-03-22)
**Commit:** 6aaa684
**Systeem:** lobos (NixOS 25.11)

## Overzicht

Hyprland is een dynamic tiling Wayland compositor toegevoegd als parallel desktop environment naast GNOME. Je kan bij elke login switchen tussen GNOME en Hyprland via de GDM session selector.

## Switchen tussen GNOME en Hyprland

### Via GDM (bij login)

1. **Logout** uit je huidige sessie
2. Op het **GDM login scherm**, klik op het **gear icon** (⚙️) rechtsonder
3. Selecteer:
   - **"Hyprland"** voor Hyprland window manager
   - **"GNOME"** voor GNOME desktop
4. **Login** met je wachtwoord
5. Je keuze wordt **onthouden** voor toekomstige logins

### Check huidige sessie

```bash
echo $XDG_CURRENT_DESKTOP
# Output: "Hyprland" of "GNOME"
```

## Activeren/Deactiveren

### Hyprland Deactiveren (volledig uitzetten)

**Stap 1: Edit system configuratie**
```bash
cd /home/wtoorren/data/git/torreirow/torreirow-nixos

# Edit hosts/lobos/configuration.nix
# Comment uit de regel:
#   ./hyprland.nix
```

**Stap 2: Edit home configuratie**
```bash
# Edit home/linux-desktop.nix
# Comment uit de regel:
#   ./hyprland-desktop
```

**Stap 3: Rebuild**
```bash
# System rebuild
sudo nixos-rebuild switch --flake .#lobos

# Home-manager rebuild
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

**Resultaat:** Hyprland wordt verwijderd uit GDM session selector. Alleen GNOME beschikbaar.

### Hyprland Reactiveren

**Stap 1: Uncomment configuratie**
```bash
# In hosts/lobos/configuration.nix:
  ./hyprland.nix    # Uncomment

# In home/linux-desktop.nix:
  ./hyprland-desktop    # Uncomment
```

**Stap 2: Rebuild**
```bash
sudo nixos-rebuild switch --flake .#lobos
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

**Resultaat:** Hyprland is weer beschikbaar in GDM session selector.

### Rollback naar Vorige Generatie

Als er problemen zijn na een rebuild:

```bash
# System rollback
sudo nixos-rebuild switch --rollback

# Home-manager rollback
home-manager switch --flake .#wtoorren@linuxdesktop --impure --rollback

# Of selecteer specifieke generatie
sudo nixos-rebuild switch --flake .#lobos --profile-name <generation-number>

# List generations
nix profile history --profile /nix/var/nix/profiles/system
```

## Keybindings Reference

### Core Keybindings

| Toets | Actie |
|-------|-------|
| **SUPER + RETURN** | Terminal (alacritty) |
| **SUPER + D** | Application launcher (rofi) |
| **SUPER + E** | File manager (nautilus) |
| **SUPER + B** | Browser (firefox) |
| **SUPER + Q** | Kill active window |
| **SUPER + F** | Fullscreen toggle |
| **SUPER + V** | Floating window toggle |
| **SUPER + P** | Pseudo tile |
| **SUPER + J** | Toggle split direction |
| **SUPER + L** | Lock screen (swaylock) |
| **SUPER + SHIFT + E** | Exit Hyprland |

### Window Navigation

| Toets | Actie |
|-------|-------|
| **SUPER + ←/→/↑/↓** | Move focus (arrow keys) |
| **SUPER + Mouse Left** | Move window (drag) |
| **SUPER + Mouse Right** | Resize window (drag) |

### Workspaces

| Toets | Actie |
|-------|-------|
| **SUPER + 1-9** | Switch to workspace 1-9 |
| **SUPER + 0** | Switch to workspace 10 |
| **SUPER + SHIFT + 1-9** | Move window to workspace 1-9 |
| **SUPER + SHIFT + 0** | Move window to workspace 10 |
| **SUPER + S** | Toggle scratchpad |
| **SUPER + SHIFT + S** | Move to scratchpad |
| **SUPER + Mouse Scroll** | Cycle workspaces |

### Screenshots

| Toets | Actie |
|-------|-------|
| **Print** | Select area → clipboard |
| **SHIFT + Print** | Screenshot → ~/Pictures/ |

### Media Keys

| Toets | Actie |
|-------|-------|
| **Volume Up/Down** | Adjust volume (5% steps) |
| **Volume Mute** | Toggle mute |
| **Brightness Up/Down** | Adjust brightness (5% steps) |
| **Play/Pause** | Media playback control |
| **Next/Previous** | Skip tracks |

## Hyprland Commands

### hyprctl (Hyprland Control)

```bash
# Monitor information
hyprctl monitors

# List all windows
hyprctl clients

# Workspace information
hyprctl workspaces

# Active window info
hyprctl activewindow

# Reload configuration
hyprctl reload

# Screen control
hyprctl dispatch dpms off    # Turn screen off
hyprctl dispatch dpms on     # Turn screen on

# Window dispatch
hyprctl dispatch killactive           # Close window
hyprctl dispatch fullscreen 0         # Toggle fullscreen
hyprctl dispatch togglefloating       # Toggle floating
hyprctl dispatch workspace 3          # Go to workspace 3
hyprctl dispatch movetoworkspace 5    # Move window to workspace 5
```

### Waybar Control

```bash
# Status
systemctl --user status waybar

# Restart
systemctl --user restart waybar

# Stop
systemctl --user stop waybar

# Start
systemctl --user start waybar

# Reload style
killall -SIGUSR2 waybar
```

### Screenshots (grim + slurp)

```bash
# Select area → clipboard
grim -g "$(slurp)" - | wl-copy

# Full screen → clipboard
grim - | wl-copy

# Select area → file
grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png

# Full screen → file
grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png

# Specific monitor (eDP-1)
grim -o eDP-1 ~/Pictures/monitor1.png
```

### Lock Screen

```bash
# Manual lock
swaylock

# Check swayidle status
systemctl --user status swayidle

# Auto-lock is configured:
# - 5 minutes idle → lock
# - 10 minutes idle → screen off
```

## Monitor Configuration

Configuratie in `home/hyprland-desktop/hyprland-config.nix`:

```nix
monitor = [
  "eDP-1,1920x1200@60,0x0,1"        # Laptop screen (left)
  "DVI-I-1,1920x1080@60,1920x0,1"   # External monitor (right)
  ",preferred,auto,1"                # Fallback
];
```

**Check huidige monitors:**
```bash
hyprctl monitors
```

**Output voorbeeld:**
```
Monitor eDP-1 (ID 0):
  1920x1200@60.00000 at 0x0
  scale: 1.00

Monitor DVI-I-1 (ID 1):
  1920x1080@60.00000 at 1920x0
  scale: 1.00
```

## Applicaties

### In Hyprland Getest

✅ **Terminal:** alacritty (native Wayland)
✅ **Browser:** Firefox (native Wayland)
✅ **File Manager:** Nautilus (GNOME)
✅ **Music Player:** Strawberry (Qt Wayland)
✅ **Text Editor:** VSCode (Electron Wayland)
✅ **Password Manager:** Bitwarden (Electron Wayland)
✅ **Messaging:** Signal, Slack, Teams (Electron Wayland)

### Default Applicaties

| Type | Applicatie | Launch |
|------|------------|--------|
| Terminal | alacritty | `SUPER + RETURN` |
| Launcher | rofi | `SUPER + D` |
| File Manager | nautilus | `SUPER + E` |
| Browser | firefox | `SUPER + B` |
| Music | strawberry | Via rofi |
| Lock Screen | swaylock | `SUPER + L` |

## Theming

### Kleurenschema (Catppuccin-inspired)

```
Background:   #1e1e2e  (dark blue-gray)
Foreground:   #cdd6f4  (light gray-blue)
Accent:       #89b4fa  (blue)
Success:      #a6e3a1  (green)
Warning:      #f9e2af  (yellow)
Error:        #f38ba8  (red)
```

### GTK Theme
- **Theme:** Adwaita-dark
- **Icons:** Papirus-Dark
- **Cursor:** Bibata-Modern-Classic (24px)
- **Font:** Sans 11

### Qt Theme
- Synced met GTK via `qt5ct`
- Native Wayland support (`QT_QPA_PLATFORM=wayland`)

## Auto-Lock & Power Management

Geconfigureerd via `swayidle` in `home/hyprland-desktop/swaylock.nix`:

- **5 minuten idle** → swaylock (screen lock)
- **10 minuten idle** → screen off (DPMS)
- **Resume** → screen on

**Grace period:** 2 seconden na lock voordat password required

## Troubleshooting

### Waybar verschijnt niet

```bash
# Check status
systemctl --user status waybar

# Logs bekijken
journalctl --user -u waybar -f

# Handmatig starten
waybar &

# Config valideren
waybar --config ~/.config/waybar/config --style ~/.config/waybar/style.css --log-level debug
```

### Qt apps geen venster

Qt apps gebruiken per-session `QT_QPA_PLATFORM=wayland`:

```bash
# Check in Hyprland sessie
echo $QT_QPA_PLATFORM
# Should output: wayland

# Test Qt app
strawberry
```

**Fix:** `QT_QPA_PLATFORM=wayland` is ingesteld in `home/hyprland-desktop/hyprland-config.nix` env variabelen.

### Monitors verkeerd geconfigureerd

```bash
# Check monitors
hyprctl monitors

# Edit config
nano ~/data/git/torreirow/torreirow-nixos/home/hyprland-desktop/hyprland-config.nix

# Rebuild home-manager
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

### Keybindings werken niet

```bash
# Check Hyprland config
hyprctl binds

# Edit config
nano ~/data/git/torreirow/torreirow-nixos/home/hyprland-desktop/hyprland-config.nix

# Reload Hyprland
hyprctl reload
```

### Screenshot niet werkt

```bash
# Check grim/slurp installed
which grim slurp wl-copy

# Test handmatig
grim -g "$(slurp)" - | wl-copy

# Check clipboard
wl-paste > /tmp/test.png
```

### Swaylock niet automatisch

```bash
# Check swayidle service
systemctl --user status swayidle

# Logs
journalctl --user -u swayidle -f

# Restart service
systemctl --user restart swayidle
```

## File Locaties

### System Config
```
hosts/lobos/hyprland.nix           - System-level Hyprland config
hosts/lobos/configuration.nix      - Import hyprland.nix
hosts/lobos/programs.nix            - Hyprland packages
```

### Home Manager Config
```
home/linux-desktop.nix              - Import hyprland-desktop
home/hyprland-desktop/
├── default.nix                     - Import coordinator
├── hyprland-config.nix             - Main Hyprland settings
├── waybar.nix                      - Status bar
├── rofi.nix                        - Launcher
├── theme.nix                       - GTK/Qt theming
├── swaylock.nix                    - Lock screen
└── dunst.nix                       - Notifications
```

### Runtime Files
```
~/.config/hypr/hyprland.conf        - Generated from hyprland-config.nix
~/.config/waybar/                   - Generated from waybar.nix
~/.config/rofi/                     - Generated from rofi.nix
~/.config/swaylock/                 - Generated from swaylock.nix
~/.config/dunst/                    - Generated from dunst.nix
```

## Logs & Debugging

```bash
# Hyprland logs
cat /tmp/hypr/$(ls -t /tmp/hypr/ | head -1)/hyprland.log

# Waybar logs
journalctl --user -u waybar -f

# Swayidle logs
journalctl --user -u swayidle -f

# Dunst logs
journalctl --user -u dunst -f

# Home-manager activation logs
journalctl --user -u home-manager-*.service
```

## Verwijderen vs Deactiveren

### Deactiveren (Aanbevolen)
- Comment uit in configuratie
- Rebuild
- Hyprland blijft in Nix store (geen disk space vrij)
- Snel te reactiveren (uncomment + rebuild)

### Volledig Verwijderen
```bash
# Deactiveren (zie boven)
# Dan garbage collect
nix-collect-garbage -d
sudo nix-collect-garbage -d

# Hyprland packages worden verwijderd uit store
# Reactiveren vereist opnieuw downloaden
```

## Backup & Restore

### Config Backup
```bash
# Alle config files zijn in git
cd /home/wtoorren/data/git/torreirow/torreirow-nixos
git log --oneline -- home/hyprland-desktop/
git log --oneline -- hosts/lobos/hyprland.nix

# Restore naar specifieke commit
git checkout <commit-hash> -- home/hyprland-desktop/
```

### Nix Generations
```bash
# List system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# List home-manager generations
home-manager generations

# Switch to generation
sudo nixos-rebuild switch --flake .#lobos --profile-name <number>
home-manager switch --flake .#wtoorren@linuxdesktop --impure --switch-generation <number>
```

## Links & Referenties

- [Hyprland Wiki](https://wiki.hypr.land/)
- [Hyprland on NixOS](https://wiki.hypr.land/Nix/Hyprland-on-NixOS/)
- [NixOS Wiki - Hyprland](https://wiki.nixos.org/wiki/Hyprland)
- [LinuxBeginnings/NixOS-Hyprland](https://github.com/LinuxBeginnings/NixOS-Hyprland) (inspiratie)
- [Catppuccin Color Scheme](https://github.com/catppuccin/catppuccin)

## Change Log

**2026-03-22** - Initial implementation (commit 6aaa684)
- System config: hyprland.nix met UWSM, portals
- Home config: complete hyprland-desktop module
- Theming: Catppuccin-inspired met Waybar
- Monitor setup: Dual screen (eDP-1 + DVI-I-1)
- Auto-lock: 5min idle, 10min screen off
- Keybinds: Complete set met SUPER modifier
