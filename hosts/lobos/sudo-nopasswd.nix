{ config, lib, pkgs, ... }:

# Sudo zonder wachtwoord voor wheel group (user wtoorren)
#
# ACTIVEREN: Uncomment de import in configuration.nix
# DEACTIVEREN: Comment de import in configuration.nix
#
# Deze file kan eenvoudig aan/uit gezet worden door de import
# in configuration.nix te (un)commenten

{
  security.sudo = {
    # Wheel group users (wtoorren) hoeven geen wachtwoord in te voeren voor sudo
    wheelNeedsPassword = false;
  };
}
