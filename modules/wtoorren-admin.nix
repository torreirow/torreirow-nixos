# wtoorren-admin als NixOS-module: Wouters shell-omgeving (home/profiles/wtoorren-admin) via
# home-manager, en optioneel het beheeraccount zelf. Eén regel maakt een nieuwe host beheerbaar:
#
#   toorren.admin.enable = true;
#
# De flake roept dit bestand aan met de inputs:
#   (import ./modules/wtoorren-admin.nix { inherit home-manager nixvim bmc race; })
# Zie docs/wtoorren-admin.md.
{ home-manager, nixvim, bmc, race }:

{ config, lib, pkgs, unstable, ... }:

let
  cfg = config.toorren.admin;
  # Sleutel `wtoorren` uit secrets/secrets.nix (dat bestand exporteert alleen recipients).
  wtoorrenKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp";
in
{
  imports = [ home-manager.nixosModules.home-manager ];

  options.toorren.admin = {
    enable = lib.mkEnableOption "het wtoorren-admin-profiel voor gebruiker wtoorren";

    aws.enable = lib.mkEnableOption ''
      ~/.aws/config met de klantaccounts (vraagt --impure bij het bouwen)'';

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Maak het beheeraccount wtoorren aan (wheel, ssh-sleutel). Zet op false als de host het
        account zelf definieert; dan regelt de module alleen home-manager en de shell.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit unstable;
          adminInputs = { inherit bmc race; };
        };
        sharedModules = [ nixvim.homeModules.default ];
        users.wtoorren = {
          imports = [ ../home/profiles/wtoorren-admin ];
          toorren.admin.aws.enable = cfg.aws.enable;
          home.stateVersion = config.system.stateVersion;
        };
      };

      programs.zsh.enable = true;
      users.users.wtoorren.shell = pkgs.zsh;
    }

    (lib.mkIf cfg.createUser {
      users.users.wtoorren = {
        isNormalUser = true;
        description = "Wouter";
        extraGroups = [ "wheel" ]
          ++ lib.optional config.networking.networkmanager.enable "networkmanager";
        openssh.authorizedKeys.keys = [ wtoorrenKey ];
      };

      # Nodig voor `nixos-rebuild --target-host`: de closure komt ongesigneerd binnen.
      nix.settings.trusted-users = [ "@wheel" ];

      # Beheer op afstand, alleen met sleutel. mkDefault: een host mag het anders regelen.
      services.openssh = {
        enable = lib.mkDefault true;
        settings = {
          PasswordAuthentication = lib.mkDefault false;
          KbdInteractiveAuthentication = lib.mkDefault false;
          PermitRootLogin = lib.mkDefault "no";
        };
      };
    })
  ]);
}
