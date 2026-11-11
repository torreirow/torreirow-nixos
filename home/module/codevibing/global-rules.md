# Git - Commits
- Never add self-promoting trailers to commit messages. Do NOT include `Co-authored-by: Claude`, `Co-Authored-By: Claude`, `Generated with Claude Code`, or any similar attribution to Claude/Anthropic. Commits are authored by me alone.

# Markdown - Styleguide
- When creating a markdown table which is not wider than 90 chars, use space padding to visually align table borders.

# Shell scripts - Portability
- Always use `#!/usr/bin/env` she-bangs (`#!/usr/bin/env bash`, `#!/usr/bin/env python3`, `#!/usr/bin/env zsh`). Never hardcode interpreter paths like `/bin/bash` or `/usr/bin/python3`.

# Terraform - TechNative
- In TechNative repositories, always run terraform with `AWS_PROFILE=technative`, e.g. `AWS_PROFILE=technative terraform plan`. Does not apply to other clients' infrastructure — check which account a repository targets before assuming.

# Context on-demand (bespaart tokens — lees het bestand pas wanneer het onderwerp speelt)
- Archiveren van een OpenSpec change, of de CHANGELOG bijwerken na een afgeronde `/opsx:apply` → lees `~/.claude/docs/openspec-workflow.md`
- Vragen of problemen rond rtk (`rtk gain`, token-besparing, `rtk: command not found`, naam-collisie met Rust Type Kit, hook-gedrag) → lees `~/.claude/docs/rtk.md`
- Iets maken of opmaken in de stijl/huisstijl van de EGH (Evangelische Gemeente Harderwijk, "Samen EGH"): slides, beamer, social, web, drukwerk, kleuren, logo → lees `~/.claude/docs/egh-stijl.md`
