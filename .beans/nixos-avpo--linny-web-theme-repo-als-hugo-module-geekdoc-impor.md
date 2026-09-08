---
# nixos-avpo
title: linny-web-theme repo als Hugo-Module (geekdoc-import)
status: completed
type: task
priority: normal
created_at: 2026-09-03T14:52:56Z
updated_at: 2026-09-03T16:51:47Z
parent: nixos-al4j
---

Nieuwe repo `github.com/torreirow/linny-web-theme` opzetten als **Hugo-Module** die geekdoc importeert.

## Todo
- [ ] repo aanmaken (torreirow); `hugo mod init github.com/torreirow/linny-web-theme` → `go.mod`
- [ ] `theme.toml` (naam, min Hugo-versie, license)
- [ ] geekdoc als module-dependency importeren (`[[module.imports]] path = github.com/thegeeklab/hugo-geekdoc`)
- [ ] `hugo mod get ./...` werkt; lege theme bouwt schoon



---
DONE (autonoom): geekdoc is GEEN Hugo-Module (geen go.mod), maar prebuilt MIT-release. Dus VENDORED linny-web-theme geekdoc v4.1.2 + Linny-layouts erbovenop -> self-contained module. Repo live: github.com/torreirow/linny-web-theme (public, tag v0.1.0). Echte 'hugo mod get' getest -> build slaagt.
