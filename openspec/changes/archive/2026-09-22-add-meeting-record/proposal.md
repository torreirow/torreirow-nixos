## Why

Er is op lobos geen manier om een meeting (Teams, Slack, Jitsi) op te nemen. De inkomende
audio en de eigen microfoon zijn twee losse stromen die nergens samenkomen: wat de anderen
zeggen gaat naar de sink, wat jij zegt gaat de app in en komt nooit langs de sink terug.
Een opname van alleen de default output levert daarom "iedereen behalve jij" op.

Er bestaat geen kant-en-klare CLI-meetingrecorder in nixpkgs; de categorie is GUI (`obs-studio`,
`gnome-sound-recorder`) of SaaS. Wat ontbreekt is een dun script om `pw-record` heen.

## What Changes

- **Nieuw**: home-manager-module `home/module/meeting-record/` met het commando `meetrec`
  (`start` / `stop` / `status` / `mix` / `transcribe` / `list`).
- **Nieuw**: twee-sporen-opname via twee onafhankelijke `pw-record`-processen — inkomend via
  `stream.capture.sink=true` (volgt de default sink), eigen stem via de default source.
- **Nieuw**: map per gesprek onder `~/Meetings/`, WAV tijdens de opname, Opus-encoding bij `stop`.
- **Nieuw**: optionele mix tot één bestand (`ffmpeg amix`), sporen blijven de bron van waarheid.
- **Nieuw**: transcriptie per spoor met whisper plus een samengevoegd, tijdgeordend transcript
  met sprekerlabels.
- **Gewijzigd**: `flake.nix` (`wtoorren@linuxdesktop`) importeert de module;
  `home/linux-desktop.nix` zet hem aan.

## Capabilities

### New Capabilities

- `meeting-record`: opname van beide kanten van een gesprek als twee gescheiden sporen, met
  nabewerking (Opus, optionele mix) en transcriptie per spoor.

### Modified Capabilities

Geen.

## Impact

- **lobos only.** De module hangt aan `wtoorren@linuxdesktop`, niet aan malandro.
- **Geen nieuwe pakketten.** PipeWire 1.6.6, `ffmpeg-full` en `openai-whisper` staan al op de
  host. `pactl` en `sox` ontbreken en worden niet gebruikt.
- **Geen systeemwijziging.** Puur home-manager; geen NixOS-module, geen daemon, geen timer.
- **Schijfruimte**: ~350 MB/uur per spoor tijdens de opname (WAV), daarna ~15 MB/uur (Opus).
- **Privacy**: het script neemt niets op uit zichzelf — `start` is altijd een expliciete
  handeling. Automatische call-detectie valt buiten deze change (bean `nixos-js5l`, deferred).
