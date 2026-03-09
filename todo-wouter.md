# Todo Wouter - Qt/Wayland fixes

## Uitgevoerde wijzigingen in `hosts/lobos/configuration.nix`

1. **QT_QPA_PLATFORM** uitgecommentarieerd - Qt kiest nu zelf
2. **enableXwayland = true** toegevoegd aan services.xserver
3. **wlr.enable** uitgecommentarieerd (dat is voor wlroots compositors, niet GNOME)
4. **xdg-desktop-portal-gnome** toegevoegd aan portals

## Te doen

### 1. Rebuild uitvoeren
```bash
sudo nixos-rebuild switch
```

### 2. Reboot (of uitloggen en weer inloggen)
```bash
reboot
```

### 3. Na inloggen, testen
```bash
echo $XDG_SESSION_TYPE   # moet 'wayland' zijn
echo $QT_QPA_PLATFORM    # moet leeg zijn
clementine
flatpak run org.musescore.MuseScore
```

## Achtergrond

Het probleem was dat `QT_QPA_PLATFORM = "xcb"` alle Qt-apps naar X11/XWayland forceerde, terwijl de sessie en portals op Wayland gericht zijn. Dit veroorzaakte onzichtbare windows bij Clementine en MuseScore.

De `wlr.enable = true` portal setting was ook verkeerd - die is voor wlroots-based compositors (Sway, Hyprland), niet voor GNOME.
