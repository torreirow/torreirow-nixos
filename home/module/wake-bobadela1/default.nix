# Home-manager module: deployt wake-bobadela1 naar ~/bin voor handmatig wekken.
# Zelfde patroon als home/module/vaultwarden-restore-test. De bron is gedeeld met
# de systeem-service: modules/wake-bobadela1/wake-bobadela1.py. Runtime-dep: ping
# (ambient op malandro). Zie OpenSpec-change add-bobadela1-wake.
{ config, lib, pkgs, ... }:

{
  home.file."bin/wake-bobadela1" = {
    executable = true;
    text = builtins.readFile ../../../modules/wake-bobadela1/wake-bobadela1.py;
  };
}
