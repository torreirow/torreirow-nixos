---
# nixos-q3p1
title: fix quarto pandoc incompatibility
status: completed
type: task
priority: normal
created_at: 2026-06-11T00:00:00Z
updated_at: 2026-06-11T00:00:00Z
---

Quarto 1.9.37 (currently installed via overlay in `overlays/wouter.nix`) fails to render any RevealJS presentation with the error:

```
Aeson exception:
Error in $: Unknown option "syntax-highlighting"
```

Quarto 1.9.37 bundles pandoc 3.7.0.2 internally. In pandoc 3.7 the `syntax-highlighting` writer option was removed or renamed, but Quarto still passes it. This affects all `.qmd` files using the `technative-theme-revealjs` format in the `technative-talks-pim` repository.

Fix: update Quarto to a release that is compatible with pandoc 3.7, or pin nixpkgs to a revision where the bundled quarto+pandoc combination works. Check the Quarto GitHub releases for a fix targeting pandoc 3.7 compatibility.

Affected host: malandro (`hosts/malandro/programs.nix` installs `quarto`).
Overlay: `overlays/wouter.nix` overrides `quarto` with extra R/Python packages — the override must be kept when updating the base version.
