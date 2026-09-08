---
# nixos-aqnt
title: Verificatie end-to-end + documentatie
status: completed
type: task
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T17:16:49Z
parent: nixos-al4j
blocked_by:
    - nixos-smw4
    - nixos-elkd
---

End-to-end verificatie + documentatie.

## Todo
- [ ] verse template-clone → `hugo mod get` + `start-web.sh` → zelfde view (andere gebruiker)
- [ ] torrlinny lokaal + malandro bouwen mét de theme → identiek
- [ ] theme-bump-procedure documenteren (`hugo mod get -u`) + fence-preprocessing-uitleg
- [ ] docs/torrlinny.md + linny-web-theme README bijwerken



DONE: end-to-end geverifieerd. (1) linny-web-theme public op github.com/torreirow/linny-web-theme (v0.1.2); echte 'hugo mod get' + build door een verse consumer werkt. (2) Template PR linden-project/linny-notebook-template#3: verse clone -> hugo mod get -> schone build (alle taxonomy/overzicht/search-pagina's). (3) torrlinny gemigreerd: web-build identiek + indexer produceert alle JSON. (4) malandro live-build via module identiek, keep-last-good intact. (5) Theme-bump-procedure (hugo mod get -u) + fence-uitleg in theme-README, WEB-README's en docs/torrlinny.md.
