## Why

Quarto 1.9.37 (installed on malandro) passes the `syntax-highlighting` writer option to pandoc, which was removed in pandoc 3.7. nixpkgs 26.05 ships pandoc 3.7.0.2, causing all RevealJS presentations to fail with `Error in $: Unknown option "syntax-highlighting"`. This blocks all `.qmd` presentation rendering until resolved.

## What Changes

- In `flake.nix`, add an inline overlay for malandro's `nixpkgs.overlays` that overrides quarto to use pandoc 3.6 from the existing `nixpkgs-2505` flake input
- Remove (or simplify) the quarto override in `overlays/default.nix` since malandro is the only host using quarto — the R/Python packages move to the inline overlay in `flake.nix`

## Capabilities

### New Capabilities

- `quarto-pandoc-pin`: Pin pandoc to 3.6 for quarto on malandro, isolated from the system pandoc version

### Modified Capabilities

*(none — no spec-level behavior changes, pure implementation fix)*

## Impact

- `flake.nix` — malandro nixpkgs.overlays gains inline quarto override
- `overlays/default.nix` — quarto override removed
- Affected host: malandro only (quarto is not installed on lobos)
- `nixpkgs-2505` is already a flake input, no new dependencies introduced
