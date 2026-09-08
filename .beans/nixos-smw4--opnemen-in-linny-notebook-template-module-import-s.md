---
# nixos-smw4
title: Opnemen in linny-notebook-template (module-import + start-web.sh)
status: completed
type: feature
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T17:00:58Z
parent: nixos-al4j
blocked_by:
    - nixos-avpo
    - nixos-oey8
---

De web-view opnemen in `linden-project/linny-notebook-template` zodat elk NIEUW notebook 'm out-of-the-box heeft.

## Todo
- [ ] `hugo-web.yaml` met de module-import (`github.com/torreirow/linny-web-theme`) + baseURL/title
- [ ] `start-web.sh` (fence-preprocess + `hugo server`) als RUNME-command
- [ ] README/CHANGELOG: hoe de web-view te starten (`hugo mod get` + start-web)
- [ ] verifiëren op een verse template-clone: `start-web.sh` → zelfde view als torrlinny



DONE: PR https://github.com/linden-project/linny-notebook-template/pull/3 (branch add-web-view). torreirow is collaborator (geen maintainer) -> PR i.p.v. direct-to-main. Toegevoegd: hugo-web.yaml (volledige site-config, want alleen params mergen), start-web.sh (fence-staging + hugo mod get + server :9999), RUNME.sh 'web', fence.py, go.mod/go.sum (pin v0.1.1), WEB-README.md. Schone hugo-build geverifieerd.
