---
# nixos-q94w
title: 'smug: torrlinny.yml wijst naar oud pad notes/torrlinny'
status: completed
type: task
priority: normal
tags:
    - smug
    - torrlinny
created_at: 2026-10-01T22:04:06Z
updated_at: 2026-10-28T16:07:13Z
---

`home/dotfiles/.config/smug/torrlinny.yml` heeft `root: /home/wtoorren/data/git/torreirow/notes/torrlinny`. De actieve sessie TorrLinny komt uit `notepad.yml` en gebruikt `~/data/git/torreirow/torrlinny`. (Verplaatst uit de home-tracker, was wtoorren-13ue.)

- [x] Nagaan of `notes/torrlinny` nog nodig is
- [x] `torrlinny.yml` naar het juiste pad zetten, of verwijderen als `notepad.yml` hem vervangt


## Summary of Changes (2026-10-28)

- `notes/torrlinny` is de oude repo `torreirow/torrlinny-site` (laatste commit 2025-01-27); niet meer nodig voor de sessie. Map niet verwijderd.
- `torrlinny.yml` (sessie "Site TorrLinny") is nu de lokale webweergave van de huidige notebook: `root: ~/data/git/torreirow/torrlinny`, window `web` draait `./start-web.sh` (poort 9999). Weggehaald: dubbele `git-sync` en `hugo server -p 1399` van de oude site, `xdg-open :1399` en `vim -c NERDTree`. git-sync en de indexer blijven in TorrLinny (`notepad.yml`).
- Actief na `home-manager switch`.
