# Home-manager module: deployt vaultwarden-restoretest.sh naar ~/bin.
# Zelfde patroon als home/module/ssh-config_hosts (export-ssh-keys.sh).
#
# Runtime-afhankelijkheden (ambient op malandro): rustic (via nixpkgs#), docker,
# sudo, curl, sqlite3, rbw, jq. rbw + jq staan in het user-profiel; de rest is
# systeem-breed. Zie openspec/changes/.../add-vaultwarden-restore-test.
{ config, lib, pkgs, ... }:

let
  module_dir = ./.;
in
{
  home.file."bin/vaultwarden-restoretest.sh" = {
    executable = true;
    text = builtins.readFile "${module_dir}/vaultwarden-restoretest.sh";
  };
}
