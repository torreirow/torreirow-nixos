# wtoorren-admin: de shell-omgeving van Wouter op hosts buiten lobos en malandro.
# Twee ingangen: modules/wtoorren-admin.nix (NixOS) en homeConfigurations."wtoorren@admin"
# (standalone, niet-NixOS). Verwacht extraSpecialArgs `unstable` en `adminInputs` (bmc, race) en
# de module nixvim.homeModules.light (of .default via toorren.admin.editor = "full"). Zie docs/wtoorren-admin.md.
{ lib, ... }:

{
  imports = [
    ./base.nix
    ./aws.nix
  ];

  options.toorren.admin.aws.enable = lib.mkEnableOption ''
    ~/.aws/config met de klantaccounts (leest ~/.aws/managed_service_accounts.json, vraagt
    --impure)'';
}
