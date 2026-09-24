# Tasks

Bean-epic: `nixos-rtcc`. Child-beans staan per blok vermeld.

## 1. Module-skelet (bean nixos-5jws)

- [x] 1.1 `home/module/meeting-record/default.nix` met `services.meeting-record`-opties
- [x] 1.2 Opties: `enable`, `targetDir`, `incoming.enable`, `mic.enable`, `opusBitrate`,
      `mixWeights`, `whisperModel`, `whisperLanguage`
- [x] 1.3 `meetrec`-script via `pkgs.writeShellApplication`, she-bang uit `writeShellApplication`
- [x] 1.4 Expliciete PATH met alleen wat er echt gebruikt wordt (pipewire, ffmpeg, coreutils)
- [x] 1.5 Module importeren in `flake.nix` (`wtoorren@linuxdesktop`)
- [x] 1.6 Module aanzetten in `home/linux-desktop.nix`

## 2. Opname (bean nixos-5jws)

- [x] 2.1 `meetrec start [naam]` → opnamemap `~/Meetings/YYYY-MM-DD-HHMM[-naam]/`
- [x] 2.2 Inkomend spoor: `pw-record -P '{ stream.capture.sink=true }'`
- [x] 2.3 Eigen spoor: kale `pw-record` (default source)
- [x] 2.4 Staatbestand met opnamemap, starttijd en beide pids
- [x] 2.5 Weigeren te starten als er al een opname loopt
- [x] 2.6 `meetrec stop` → SIGINT beide processen, wachten tot de WAV-headers geflusht zijn
- [x] 2.7 `meetrec status` → map, verstreken tijd, bestandsgroottes, gekoppelde bronnen
- [x] 2.8 `meetrec status` herkent een omgevallen opnameproces
- [x] 2.9 `meetrec list` → afgeronde opnames

## 3. Nabewerking (bean nixos-w6hy)

- [x] 3.1 Opus-encoding bij `stop`, 32 kbit/s mono, met `nice`/`ionice`
- [x] 3.2 WAV pas verwijderen na geslaagde encoding
- [x] 3.3 Bij mislukte encoding: WAV laten staan en de fout melden

## 4. Mix (bean nixos-gx0e)

- [x] 4.1 `meetrec mix <map>` → `ffmpeg amix` van beide sporen naar `meeting.opus`
- [x] 4.2 Sporen blijven staan
- [x] 4.3 Niveaubalans instelbaar via `mixWeights`

## 5. Transcriptie (bean nixos-tdv7)

- [x] 5.1 `meetrec transcribe <map>` → whisper per spoor naar SRT
- [x] 5.2 `merge-transcripts.py` → één tijdgeordend transcript met `[ik]`/`[anderen]`-labels
- [x] 5.3 `nice`/`ionice`, expliciet als losse stap na de opname

## 6. Documentatie

- [x] 6.1 `home/module/meeting-record/README.md`
- [x] 6.2 Verwijzing in `CLAUDE.md` (contextbestanden-lijst)
- [x] 6.3 CHANGELOG-entry onder `## NEXT VERSION`

## 7. Verificatie (bean nixos-4dd0)

- [x] 7.1 `nix build` van de home-manager-activationPackage slaagt
- [x] 7.2 Echte proefopname: start → stop → twee Opus-bestanden met signaal erin
- [x] 7.3 `meetrec status` klopt tijdens en na de opname
- [x] 7.4 `meetrec mix` levert een afspeelbaar bestand met beide kanten erin
- [x] 7.5 `meetrec transcribe` levert een samengevoegd transcript met labels
- [x] 7.6 Default-sink wisselen tijdens een lopende opname → inkomend spoor loopt door
- [x] 7.7 Weigering bij dubbele `start`, en `stop` zonder lopende opname faalt niet
- [ ] 7.8 Echte meeting-proef met Teams, Slack en Jitsi — handwerk, blijft open in bean
      `nixos-4dd0`. De opnameketen zelf is geverifieerd met een echte proefopname; wat hier
      nog bij moet is een gesprek met daadwerkelijke deelnemers.

## 8. Tijdens de bouw bijgekomen

- [x] 8.1 `shq`-helper in plaats van `lib.escapeShellArg`: die laat "veilige" strings
      ongequoteerd, waardoor `WHISPER_LANGUAGE=nl` ontstond en shellcheck (SC2209) de build brak
- [x] 8.2 `set -e`-valkuilen weggewerkt: `[ test ] && actie` als laatste statement in een
      if-blok of functie laat het hele compound falen
- [x] 8.3 `trap '' HUP` vóór de exec in `spawn_recorder`, zodat een opname het sluiten van de
      terminal overleeft (een genegeerde dispositie overleeft execve)
- [x] 8.4 `merge_transcripts_test.py`: 16 assertions over volgorde, labels, meerregelige
      blokken, een leeg spoor en een ontbrekend spoor
