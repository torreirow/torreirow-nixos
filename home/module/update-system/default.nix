# Home-manager module: `update-system` voor lobos en malandro -- firmware via
# fwupd, systeem via de flake-checkout (git pull + nixos-rebuild + home-manager)
# en daarna oude generaties opruimen. Vervangt het apt-script dat als agenix-
# secret op /data/scripts/update_laptop.sh stond. Gebruik: `sudo update-system
# fetch|update`.
{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "update-system" (builtins.readFile ./update-system.sh))
  ];
}
