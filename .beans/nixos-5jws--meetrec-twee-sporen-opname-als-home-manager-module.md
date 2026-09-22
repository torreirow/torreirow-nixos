---
# nixos-5jws
title: 'meetrec: twee-sporen-opname als home-manager module'
status: completed
type: feature
priority: high
created_at: 2026-09-22T09:00:36Z
updated_at: 2026-09-22T10:05:30Z
parent: nixos-rtcc
---

Home-manager module `home/module/meeting-record/` met een `meetrec`-script, in het patroon van `home/module/remarkable-sync` en `home/module/vaultwarden-restore-test`.

## Taken
[ ] `home/module/meeting-record/default.nix` aanmaken en importeren waar de andere home-modules hangen
[ ] `meetrec start` -> twee `pw-record`-processen, pidfile per opname
[ ] inkomend spoor: `pw-record -P '{ stream.capture.sink=true }' anderen.wav`
[ ] eigen spoor: kale `pw-record ik.wav` (pakt de default source)
[ ] `meetrec stop` -> beide processen netjes beeindigen (SIGINT, wachten tot de WAV-header geflusht is)
[ ] `meetrec status` -> loopt er iets, sinds wanneer, aan welke bronnen hangen de streams
[ ] she-bang `#!/usr/bin/env bash`

## Besluit
Geen apparaatnamen of node-id's in het script; WirePlumber doet de routing. Zie epic.

## Let op
`pactl` en `sox` staan NIET op lobos. Alleen `pw-*` en ffmpeg gebruiken.


## Summary of Changes

Home-manager-module `home/module/meeting-record/` met `meetrec` (start/stop/status/list/mix/
transcribe), gebouwd met `pkgs.writeShellApplication` zodat shellcheck bij elke build meekijkt.
Geïmporteerd in `flake.nix` (`wtoorren@linuxdesktop`), aangezet in `home/linux-desktop.nix`.

Geverifieerd met een echte proefopname: beide opnemers koppelden meteen aan de juiste bronnen
(KT USB monitor en de USB Composite mic), dubbele `start` wordt geweigerd, `stop` zonder opname
faalt netjes met exit 1.

Drie dingen die tijdens de bouw stukliepen en gerepareerd zijn:
- `lib.escapeShellArg` quoot "veilige" strings NIET, dus ontstond `WHISPER_LANGUAGE=nl` — en `nl`
  is een commando, dus shellcheck (SC2209) brak de build. Eigen `shq`-helper die altijd quoot.
- `[ test ] && actie` als laatste statement in een if-blok of functie laat het hele compound
  falen; met `set -euo pipefail` (writeShellApplication) knalt het script er dan uit. Omgezet
  naar `if`-blokken.
- Zonder `trap '' HUP` vóór de exec sterft de opname zodra je de terminal sluit, want de
  opnemers zitten in dezelfde procesgroep. Een genegeerde signaaldispositie overleeft execve, dus
  die trap vóór `exec pw-record` lost het op.
