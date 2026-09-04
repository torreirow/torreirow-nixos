{ config, pkgs, unstable, ... }:

{
  # atuin komt nu rechtstreeks uit nixpkgs unstable (unstable.atuin) i.p.v. een
  # custom rustPlatform-build. Geen overlay meer nodig.
  nixpkgs.overlays = [ ];
}
