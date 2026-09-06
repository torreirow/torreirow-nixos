---
# nixos-vd2b
title: torrlinny-notebook migreren naar de theme-import
status: completed
type: feature
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T17:07:48Z
parent: nixos-al4j
blocked_by:
    - nixos-b8hq
    - nixos-s201
    - nixos-ej5n
---

Het notebook `torreirow/torrlinny` migreren van de eigen web-config naar de theme-import.

## Todo
- [ ] `hugo-web.yaml` afslanken tot de module-import + notebook-specifieke overrides
- [ ] eigen `layouts/*` (die nu in de theme zitten) uit het notebook halen
- [ ] `start-web.sh` gelijktrekken met de template-runner (fence-preprocess)
- [ ] lokaal verifiëren dat de view identiek blijft



DONE: torrlinny gemigreerd naar theme-import (github.com/torreirow/torrlinny@main, commit 772db1f). hugo-web.yaml importeert de module (go.mod/go.sum pinnen v0.1.2); geekdoc+PaperMod-submodules verwijderd; menu-filetree.html gepromoveerd naar de theme; start-web.sh = hugo mod get + fence-staging + server :9999. Lokaal geverifieerd: web-build identiek (taxonomie-zijbalk, Created/Updated, overzichten, search) EN indexer-build produceert alle JSON (exit 0).
