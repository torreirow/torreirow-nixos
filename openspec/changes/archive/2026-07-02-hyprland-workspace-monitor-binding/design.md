## Context

Hyprland beheert workspaces globaal: bij twee monitoren landen workspaces op de monitor waar de focus was. Na een herstart of herverbinding van het externe scherm (DP-10) verdwijnt de eerder geldende verdeling. Apps als Slack, Teams en Firefox belanden dan op wisselende schermen.

Hyprland biedt twee native mechanismes:
1. `workspace` rules met `monitor:` en `persistent:true` — koppelt een workspace permanent aan een monitor
2. `windowrule` met `workspace N silent` — stuurt een app bij openen altijd naar workspace N

Beide zijn declaratief en leven in de NixOS Hyprland-config.

## Goals / Non-Goals

**Goals:**
- Workspaces 1 en 2 zijn vaste startschermen voor resp. extern en laptop
- Workspace 3 (Slack/Teams) altijd op laptop, workspace 4 (Firefox) altijd op extern
- Alle workspaces 1-10 bestaan altijd (persistent), ook als leeg
- Graceful fallback: bij geen extern scherm werkt alles op eDP-1

**Non-Goals:**
- Dynamische workspace-herverdeling op basis van aangesloten schermen
- Wayle of waybar aanpassingen
- Overige apps automatisch toewijzen (buiten scope van dit voorstel)

## Decisions

### Workspace binding via `workspace` rule, niet via `wsbind` dispatch

Hyprland heeft zowel een statische `workspace` config-rule als een runtime `hyprctl dispatch wsbind`. Gekozen voor de statische config-rule omdat deze declaratief is, in NixOS beheerd wordt, en automatisch hersteld wordt na herstart.

Alternatief overwogen: `exec-once` met `hyprctl dispatch wsbind` — verworpen omdat het een race condition heeft bij opstarten en niet declaratief is.

### `persistent:true` voor alle workspaces 1-10

Zonder `persistent:true` bestaan lege workspaces niet tot je er naartoe navigeert. De wayle workspace-indicator toont dan gaten. Met `persistent:true` zijn alle workspaces altijd zichtbaar in de bar.

### `silent` in windowrule

`workspace N` zonder `silent` zou bij het openen van de app direct naar die workspace switchen — disruptief bij autostart. Met `silent` opent de app op de achtergrond op de juiste workspace.

### Workspace-nummering: 1=extern, 2=laptop

Contra-intuïtief (1 is het "primaire" getal, maar extern is niet altijd beschikbaar). Afweging: de gebruiker wil extern als primaire werkplek wanneer beschikbaar. WS 1 als extern default past daarbij. Bij ontbreken extern scherm gelden WS 1-4 gewoon allemaal op eDP-1.

## Risks / Trade-offs

- **teams-for-linux class naam onzeker** → Mitigation: class verifiëren met `hyprctl clients` na eerste start; windowrule aanpassen indien nodig. Mogelijke klassen: `teams-for-linux`, `Teams`, `MSTeams`.
- **Workspace binding werkt alleen als monitor is aangesloten bij Hyprland-start** → Bij hot-plug na start worden workspaces niet automatisch herverdeeld. Mitigation: Hyprland herdistribueert workspaces bij monitor-events; `persistent:true` zorgt dat ze terugkomen op de juiste monitor.
- **Conflicten met bestaande windowrules** → Bestaand `suppress_event maximize` en float-rules in windows.nix; workspace-regels komen daar bovenop zonder conflict.

## Migration Plan

1. `workspace` bindings toevoegen aan `default.nix` settings block
2. `windowrule` entries toevoegen aan `windows.nix`
3. `home-manager switch` uitvoeren
4. Hyprland herstarten (of logout/login) zodat persistent workspaces actief worden
5. Slack, Teams en Firefox openen om windowrule te verifiëren
6. `hyprctl clients | grep class` gebruiken als class-naam van Teams afwijkt
