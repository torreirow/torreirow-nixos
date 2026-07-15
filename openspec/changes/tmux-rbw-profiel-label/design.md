## Context

`home/tmux.nix` definieert de tmux-configuratie inclusief een `status-right` met een rbw lock-indicator. De huidige implementatie bevat een foutieve inline shell if-structuur die `$RBW_PROFILE` niet correct uitleest en de variabele niet vertaalt naar een leesbaar label.

`RBW_PROFILE` wordt handmatig gezet via `export RBW_PROFILE=<waarde>` en is beschikbaar in de tmux-server omgeving omdat `rbw` (de bitwarden CLI) deze variabele al leest vanuit diezelfde omgeving voor de `rbw unlocked` check.

## Goals / Non-Goals

**Goals:**
- Profielnaam vertalen naar een kort label (bv. "TN", "WT") via een declaratieve Nix-mapping
- De shell-logica isoleren in een `writeShellScript` (testbaar, leesbaar, los van de config-string)
- De `status-right` string clean houden door enkel `#(${rbwStatus})` te bevatten

**Non-Goals:**
- Automatisch wisselen van profiel
- Meerdere gelijktijdige profielen tonen
- Integratie met andere password managers

## Decisions

### 1. Nix attrset als bron van waarheid voor profielen

**Beslissing:** `rbwProfiles = { "technative" = "TN"; }` als Nix attrset, met `rbwDefaultLabel = "WT"` als fallback.

**Reden:** Profielen toevoegen of aanpassen hoeft enkel op één plek in de Nix-code. Nix genereert de `case`-body automatisch via `lib.concatStringsSep` en `lib.mapAttrsToList`, waardoor de shell-code nooit handmatig bijgewerkt hoeft te worden.

**Alternatief overwogen:** Hardcoded case-statement in de shell string — afgewezen omdat dit twee plekken vereist bij uitbreiding.

### 2. `writeShellScript` in plaats van inline `#(...)`

**Beslissing:** De rbw-logica in een `pkgs.writeShellScript "rbw-status"` plaatsen, vergelijkbaar met het bestaande `beans-tui-popup` patroon in hetzelfde bestand.

**Reden:** Inline shell in een tmux config-string is slecht leesbaar en moeilijk te debuggen. Een apart script is testbaar via de shell en houdt de `extraConfig` string clean.

### 3. `rbw unlocked` voor lock-detectie (ongewijzigd)

**Beslissing:** De bestaande `rbw unlocked` check blijft. Exit code 0 = unlocked, non-zero = locked.

**Reden:** Werkt al correct in de huidige omgeving; geen reden om te wijzigen.

## Risks / Trade-offs

- **RBW_PROFILE niet gezet** → fallback naar `rbwDefaultLabel` ("WT"). Gedrag is voorspelbaar.
- **Nix attrset volgorde** → `lib.mapAttrsToList` is alfabetisch gesorteerd, maar volgorde in een `case`-statement is irrelevant (eerste match wint, `*` is altijd laatste).
- **tmux status interval** → `#()` wordt periodiek herschaald; label-wijziging na `export RBW_PROFILE` is zichtbaar bij de volgende refresh (standaard elke 15 seconden).
