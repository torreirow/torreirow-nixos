## 1. flake.nix aanpassen

- [x] 1.1 `nixpkgs-2505` stond al in de `outputs` parameter destructuring
- [x] 1.2 Inline overlay toegevoegd aan lobos én malandro met pandoc 3.8.3 derivation + quarto 1.9.38 overrideAttrs

## 2. Opruimen shared overlay

- [x] 2.1 Quarto override blok verwijderd uit `overlays/default.nix`

## 3. Verifiëren

- [x] 3.1 `dry-build .#lobos` evalueert correct (pandoc-3.8.3.drv + quarto-1.9.38.drv aangemaakt)
- [x] 3.2 `nixos-rebuild switch --flake .#lobos` succesvol afgerond
