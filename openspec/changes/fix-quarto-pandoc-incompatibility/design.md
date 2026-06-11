## Context

The NixOS Quarto derivation wraps the Quarto binary and sets `QUARTO_PANDOC` via `--set-default`, meaning the nixpkgs `pandoc` package is used unless overridden. The `quarto.override { pandoc = ...; }` pattern works because `pandoc` is a named parameter in the derivation.

Current state:
- `overlays/default.nix` overrides quarto with `extraRPackages` and `extraPythonPackages` for all hosts
- malandro is the only host that installs quarto (`hosts/malandro/programs.nix` line 69)
- `nixpkgs-2505` (pandoc 3.6) is already declared as a flake input — no new inputs needed

## Goals / Non-Goals

**Goals:**
- Quarto on malandro uses pandoc 3.6 instead of 3.7.0.2
- R/Python package overrides (reticulate, plotly, numpy, etc.) are preserved
- No new flake inputs introduced

**Non-Goals:**
- Fixing the underlying Quarto 1.9.37 bug (upstream issue)
- Updating Quarto to a newer version
- Changing pandoc for any other tool on any host

## Decisions

**Decision: inline overlay in flake.nix, not a modified overlays/default.nix**

The quarto pandoc pin is malandro-specific. Putting it in the shared overlay would force all hosts to build against nixpkgs-2505's pandoc, which is unnecessary. An inline overlay on malandro's `nixpkgs.overlays` keeps the scope correct and avoids threading `inputs` through the overlay file.

Alternative considered: make `overlays/default.nix` accept `inputs` as a first argument (`inputs: final: prev: ...`) and call it as `(import ./overlays inputs)`. Rejected: requires changing all three overlay call sites in flake.nix (lines 68, 98, 211) and couples the shared overlay to a host-specific concern.

**Decision: remove quarto override from overlays/default.nix**

Since malandro is the only quarto user, the override in the shared overlay serves no purpose after the inline overlay is added. Leaving both would cause the inline overlay to override the shared one anyway (last overlay wins), but having dead code in the shared overlay is confusing.

**Decision: use nixpkgs-2505.legacyPackages.x86_64-linux.pandoc**

`nixpkgs-2505` is a flake input that resolves to the nixos-25.05 channel, which has pandoc 3.6. Using `legacyPackages.x86_64-linux` is the standard way to access packages from a non-followed nixpkgs input in a flake.

## Risks / Trade-offs

- **pandoc version drift** → malandro will stay on pandoc 3.6 until quarto is updated. Other tools on malandro that use the system pandoc are unaffected (they use the system pandoc, not `QUARTO_PANDOC`).
- **nixpkgs-2505 input ages** → the 25.05 channel is already pinned in flake.lock and used by other things; no additional maintenance burden.
- **Future Quarto update** → when nixpkgs eventually ships a Quarto compatible with pandoc 3.7, the pandoc override and nixpkgs-2505 input can both be removed.
