---
# nixos-v0p3
title: 'mpenzi: Plasma-defaults en apps'
status: todo
type: task
created_at: 2026-11-04T16:26:56Z
updated_at: 2026-11-04T16:26:56Z
parent: nixos-54um
blocked_by:
    - nixos-nkux
---

Plasma 6 Windows-vriendelijk inrichten en de apps installeren.

- Plasma-defaults als systeem-defaults onder `/etc/xdg` (bv. `environment.etc."xdg/kdeglobals"`,
  `kglobalshortcutsrc`): Win+E = Dolphin, Win+Shift+S = Spectacle rechthoek, Win+L = vergrendelen,
  dubbelklik. Gebruiker moet alles kunnen overschrijven (dus geen plasma-manager).
- Firefox via `programs.firefox` als standaardbrowser; `google-chrome` ernaast.
- `onlyoffice-desktopeditors`, `fonts.packages = [ corefonts vista-fonts ]`, `nextcloud-client` (XDG-autostart),
  `thunderbird`, `jitsi-meet-electron`, `zoom-us`, `bitwarden-desktop`.
- Canva: desktopentry die Chrome start met `--app=https://www.canva.com` (eigen naam + icoon).
- `services.flatpak.enable` + Flathub-remote (bv. oneshot-service), Discover aanwezig.
- `../../modules/printer-thuis.nix` importeren.
