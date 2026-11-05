# home-manager-profiel van maaike: alleen app-standaarden, geen Plasma-instellingen (die blijven
# de /etc/xdg-defaults uit hosts/mpenzi/plasma.nix, die zij zelf mag aanpassen).
# Wordt geladen door modules/maaike-apps.nix. Zie docs/maaike-app-defaults.md.
{ lib, pkgs, ... }:

let
  seeds = import ./seeds.nix { inherit pkgs lib; };
in
{
  # Kopie in plaats van home.file: de apps schrijven hun eigen config, een store-link is
  # read-only. Bestaande bestanden blijven staan; herstellen gaat met `herstel-app`.
  home.activation.seedAppDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${seeds.script} ${lib.concatStringsSep " " (lib.attrNames seeds.apps)}
  '';
}
