## Context

Hyprland draait met monitor scale 1.25 op eDP-1. Wayland-native apps schalen mee; XWayland apps niet, omdat `xwayland.force_zero_scaling = true` staat (voorkomt wazige compositor-upscale). Fonts in X11 apps zien er daardoor kleiner uit.

`gsettings org.gnome.desktop.interface text-scaling-factor` wordt door GTK3/GTK4 Wayland apps gelezen en biedt een runtime-aanpasbare font scale buiten GNOME. Er is geen centrale "large text" knop in Hyprland.

## Goals / Non-Goals

**Goals:**
- X11/XWayland apps tonen fonts even groot als Wayland apps (Xft.dpi fix)
- Gebruiker kan met keybindings de tekstgrootte stapsgewijs aanpassen (0.1 per stap)
- Visuele bevestiging na elke aanpassing via wayle notificatie popup

**Non-Goals:**
- Schalen van Waybar, Hyprlock, Mako, SwayNC (die hebben eigen font configs)
- Persistent opslaan van de gekozen schaal tussen sessies (gsettings persistent via dconf)
- Ondersteuning voor Qt-apps via text-scaling-factor (Qt leest dit niet)

## Decisions

### Xft.dpi via xresources (niet via env var)

`home.sessionVariables.GDK_DPI_SCALE` en vergelijkbare env vars werken inconsistent. `xresources.properties."Xft.dpi"` is de standaard X11 manier en wordt door alle X11/XWayland apps gelezen.

Waarde: `96 × 1.25 = 120`. `force_zero_scaling = true` blijft staan — Xft.dpi informeert apps over DPI zonder compositor-upscale.

### gsettings text-scaling-factor voor Wayland GTK apps

`text-scaling-factor` werkt buiten GNOME voor alle GTK3/GTK4 Wayland apps. Het is runtime-aanpasbaar (geen rebuild), persistent via dconf, en het dichts bij GNOME's "Large Text".

Alternatief `gtk.font.size` in home-manager vereist `home-manager switch` en herstart van apps — onbruikbaar als snelle toggle.

### awk voor float rekenen

Bash heeft geen native float support. `awk` is altijd beschikbaar (deel van GNU coreutils in NixOS) en vereist geen extra dependency.

Alternatief `python3 -c` werkt ook maar is zwaarder voor een simpele berekening.

### notify-send als feedback

Wayle heeft geen `osd`-commando voor custom berichten. De OSD voor volume/brightness is intern en luistert naar dbus events. `notify-send` verschijnt via wayle's notificatie popup — zelfde ecosysteem, iets andere presentatie.

## Risks / Trade-offs

- [Qt apps negeren text-scaling-factor] → Acceptabel; Qt apps gebruiken de monitor scale al correct als Wayland-native
- [X11 apps pikken Xft.dpi pas op na herstart] → Acceptabel; zelfde gedrag als bij elke Xresources wijziging
- [text-scaling-factor + monitor scale 1.25 = gestapeld effect] → Bewust; gebruiker kiest de extra stappen zelf
