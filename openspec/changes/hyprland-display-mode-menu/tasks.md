# Tasks

## 1. Spike (met extern scherm aangesloten)

- [ ] 1.1 Zet handmatig `hyprctl keyword monitor <EXT>,disable` en daarna weer aan, en `eDP-1,disable` + weer aan; verifieer met `socat` op socket2 of `monitorremoved`/`monitoraddedv2` vuren, en leg de uitkomst vast in design.md (decision 5)
- [ ] 1.2 Zet handmatig `<EXT>,preferred,auto,1,mirror,eDP-1`; verifieer dat het externe scherm het laptopbeeld toont, noteer hoe de schaling eruitziet en zet daarna terug naar uitgebreid

## 2. Menu-script en binding

- [x] 2.1 Schrijf het script `hyprland-display-mode` (writeShellApplication: detectie via `hyprctl monitors all -j`, fuzzel-menu met 4 standen, regels uit design decision 1 in de juiste volgorde, notify-send zonder extern scherm); verifieer dat de HM-build slaagt (shellcheck in writeShellApplication)
- [x] 2.2 Haal de eDP-1-regel naar één gedeelde waarde (`home/hyprland/laptop-monitor.nix`, geïmporteerd door `default.nix`, het script en de binder); verifieer dat de gegenereerde `hyprland.conf` nog `monitor=eDP-1,preferred,auto,1.25` bevat
- [x] 2.3 Voeg `SUPER SHIFT, P` toe in `bindings.nix` plus een regel in de hulptekst; verifieer dat de binding in `hyprland.conf` staat en dat SUPER+P nog `pseudo` is

## 3. Vangnet en workspaces

- [x] 3.1 Breid `hyprland-workspace-binder` uit: bij `monitorremoved` eDP-1 aanzetten als die uit staat en er geen andere actieve output is; `bind_workspaces` slaat de eDP-1-binding over als eDP-1 niet actief is; verifieer dat de HM-build slaagt
- [ ] 3.2 Als de spike (1.1) liet zien dat de events niet vuren: laat het script na het toepassen de binding zelf aanroepen; anders deze taak afvinken als "niet nodig"

## 4. Test (user, met extern scherm)

- [x] 4.1 Draai `home-manager switch`; verifieer dat beide user-services draaien (`systemctl --user status hyprland-workspace-binder`)
- [ ] 4.2 Doorloop Uitgebreid → Klonen → Alleen extern → Alleen laptop → Uitgebreid via SUPER+SHIFT+P; verifieer per stand het beeld, en dat SUPER+1..0 alle workspaces op een zichtbaar scherm brengt
- [ ] 4.3 Escape in het menu; verifieer dat er niets verandert
- [ ] 4.4 In Alleen extern de kabel eruit; verifieer dat het laptopscherm vanzelf aangaat met alle workspaces bereikbaar
- [ ] 4.5 Zonder extern scherm SUPER+SHIFT+P; verifieer de melding en dat er niets verandert
- [ ] 4.6 Na Klonen een `hyprctl reload`; verifieer dat de opstelling weer Uitgebreid is

## 5. Afronding

- [ ] 5.1 Werk CHANGELOG (`## NEXT VERSION` → Added) en CLAUDE.md (sessie-entry) bij; verifieer dat beide SUPER+SHIFT+P en het vangnet noemen
