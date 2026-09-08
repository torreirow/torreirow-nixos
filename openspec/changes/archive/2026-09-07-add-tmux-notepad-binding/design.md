## Context

Zie `proposal.md` - Why. `home/tmux.nix` heeft al één smug-launcher (`bind C-c`, regel ~115)
die de `spg`-layout in een **popup** start en met de `TMUX= tmux attach`-truc attacht. Die truc
is nodig omdat je binnen dezelfde tmux-server niet mag attachen (nesting-error). Voor notepad
willen we juist blijvend in de sessie zitten, wat binnen dezelfde server met `switch-client`
kan — schoner dan de popup+attach-omweg.

Kernconstraint: de smug-config `home/dotfiles/.config/smug/notepad.yml` zet
`session: TorrLinny`. `smug start notepad` maakt dus een sessie die `TorrLinny` heet, niet
`notepad`. Alle sessie-targets moeten daarop matchen.

## Goals / Non-Goals

**Goals:**
- Eén prefix-keybinding die notepad idempotent opent en er via `switch-client` naartoe springt.
- Consistent qua stijl met de bestaande smug-launcher, maar zonder popup.

**Non-Goals:**
- De smug-config `notepad.yml` wijzigen (o.a. de sessienaam `TorrLinny` hernoemen).
- Extra bindings voor andere smug-layouts.
- De bestaande `C-c`/spg-binding aanpassen.

## Decisions

**`switch-client` i.p.v. popup+attach.** Notepad is een volwaardige werkomgeving (vim,
git-sync, hugo op 1314) waar je in blijft, geen transient overlay. `switch-client -t TorrLinny`
brengt de huidige client volledig naar de sessie. Alternatief (popup zoals spg) verworpen: een
90%-overlay met `attach` past bij even-kijken-en-weg, niet bij blijvend werken.

**Idempotentie via `has-session` op `TorrLinny`.** `tmux has-session -t TorrLinny 2>/dev/null ||
smug start notepad --detach`, gevolgd door `switch-client -t TorrLinny`. Bestaat de sessie →
alleen switchen; anders eerst gedetacheerd starten (`--detach`, zodat smug niet in de
keybinding-context probeert te attachen) en dan switchen. Vorm:

```
bind N run-shell 'tmux has-session -t TorrLinny 2>/dev/null || smug start notepad --detach' \; \
       switch-client -t TorrLinny
```

**Target `TorrLinny`, niet `notepad`.** Bewuste keuze om op de echte sessienaam te matchen. Een
`has-session -t notepad` zou altijd missen → elke keer een dubbele `smug start`. Vastgelegd als
expliciete requirement in de spec zodat de valkuil niet terugkomt.

**Toets `N`.** Vrij; bezet zijn `T`, `J`, `B`, `C-c`, `g`, `r`. `N` = notepad, mnemonisch.

## Risks / Trade-offs

- [Race: `smug start --detach` is nog niet klaar wanneer `switch-client` vuurt] → smug maakt de
  tmux-sessie vroeg in zijn opstart aan; `switch-client` faalt hooguit één keer stil als de
  sessie er nog niet is. Mitigatie indien merkbaar: bij problemen `switch-client` in hetzelfde
  `run-shell` na de start zetten. Eerst de simpele vorm; alleen bijstellen als het in de praktijk
  hapert.
- [Sessienaam `TorrLinny` verandert in `notepad.yml`] → dan breekt de binding. Mitigatie: de spec
  koppelt binding en sessienaam expliciet; wijzig je de een, wijzig je de ander.
- [Timing t.o.v. de `SSH_CONNECTION`-prefixswitch (C-a lokaal / C-b via SSH)] → geen; `N` is een
  gewone binding onder de actieve prefix en erft die automatisch.
