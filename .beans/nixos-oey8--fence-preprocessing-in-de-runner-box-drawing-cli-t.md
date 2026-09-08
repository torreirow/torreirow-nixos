---
# nixos-oey8
title: Fence-preprocessing in de runner (box-drawing CLI-tabellen)
status: completed
type: feature
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T17:00:58Z
parent: nixos-al4j
blocked_by:
    - nixos-avpo
---

Box-drawing CLI-tabellen fencen — als **preprocessing in de gedeelde runner** (optie a), niet in de theme.

## Todo
- [ ] `fence.py` (of awk/Go-equivalent) meeleveren: contigue box-drawing-runs (U+2500–U+259F) → ```text-fence
- [ ] draait op een KOPIE/staging van content vóór hugo (bron ongemoeid), idempotent
- [ ] inbouwen in de runner (`start-web.sh`/RUNME) zodat elke gebruiker het krijgt
- [ ] Python-dep documenteren (of portable herschrijven)

## Notitie
Kan geen theme-ding zijn: een theme ziet al-geparseerde content; de fix moet vóór goldmark draaien.



DONE: fence.py (box-drawing U+2500-U+259F -> text-fence) meegeleverd in de gedeelde runner start-web.sh, op een STAGING-kopie (bron ongemoeid, idempotent). In de template (PR #3) en straks torrlinny + malandro-build. Python3-dep gedocumenteerd in WEB-README.
