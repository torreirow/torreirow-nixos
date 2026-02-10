{
  description = "Wouters super conf";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-luca.url = "github:Caspersonn/nixpkgs";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-2311.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    bmc.url = "github:wearetechnative/bmc";
    #bmc.url = "github:wearetechnative/bmc?rev=3cfa158a5a622df59686537c68b256ecb4bff74c";
    race.url = "github:wearetechnative/race";
    jsonify-aws-dotfiles.url = "github:wearetechnative/jsonify-aws-dotfiles";
    dirtygit.url = "github:mipmip/dirtygit";
    openspec.url = "github:mipmip/OpenSpec";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homeage = {
      url = "github:jordanisaacs/homeage";
      # Optional
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };



  outputs = inputs@{ self, nixpkgs, nixpkgs-2305,  nixpkgs-2311, unstable, home-manager, agenix, bmc, homeage, dirtygit, race, jsonify-aws-dotfiles, nixpkgs-2405, nixpkgs-2411, nixpkgs-2505, nixpkgs-luca, openspec}: 
  let 
    system = "x86_64-linux";
    extraPkgs= { pkgs, ...}: {
      environment.systemPackages = [ 
        bmc.packages."${system}".bmc 
        dirtygit.packages."${system}".dirtygit
        race.packages."${system}".race 
        jsonify-aws-dotfiles.packages."${system}".jsonify-aws-dotfiles
        openspec.packages."${system}".default
      ];
    };

    pkgs-2411 = import nixpkgs-2411 {
          system = system;
            };

  in
  {
  ## wtremove inherit unstable;


  ## LOBOS config START
  nixosConfigurations.lobos = nixpkgs.lib.nixosSystem {
    modules =
      let
        system = "x86_64-linux";
        defaults = { pkgs, ... }: {
          nixpkgs.overlays = [(import ./overlays) (import ./overlays/cooklang.nix)
        
          ];
          _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2305 = import nixpkgs-2305 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2311 = import nixpkgs-2311 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2411 = import nixpkgs-2411 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-luca = import nixpkgs-luca { inherit system; config.allowUnfree = true; };
          _module.args.agenix = inputs.agenix.packages.${system}.default;

        };


        

      in [
        defaults
        extraPkgs
        agenix.nixosModules.default
        ./hosts/lobos/configuration.nix
        ./modules/tnaws.nix
        ./modules/general-desktop.nix
        ./modules/jiratui.nix
      ];
    };
### LOBOS config END
### MALANDRO config START
  nixosConfigurations.malandro = nixpkgs.lib.nixosSystem {
    modules =
      let
        system = "x86_64-linux";
        defaults = { pkgs, ... }: {
          nixpkgs.overlays = [(import ./overlays)];
          _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2305 = import nixpkgs-2305 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2311 = import nixpkgs-2311 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2411 = import nixpkgs-2311 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-luca = import nixpkgs-luca { inherit system; config.allowUnfree = true; };
          _module.args.agenix = inputs.agenix.packages.${system}.default;

        };


        

      in [
        defaults
        extraPkgs
        agenix.nixosModules.default
        ./hosts/malandro/configuration.nix
        ./modules/tnaws.nix
      ];
    };
### MALANDRO config END

  ## KARLAPI config START
  nixosConfigurations.karlapi = nixpkgs.lib.nixosSystem {
    modules =
      let
        system = "x86_64-linux";
        defaults = { pkgs, ... }: {
          _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2305 = import nixpkgs-2305 { inherit system; config.allowUnfree = true; };
        };
      in [
        defaults
        ./hosts/karlapi/configuration.nix
        ./modules/tnaws.nix
      ];
    };
### KARLAPI config END

  ### LINUX HOMEMANAGER START ROOT
  homeConfigurations."root@linuxdesktop" = home-manager.lib.homeManagerConfiguration(
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      linux-defaults = {pkgs,config,homeage,...}: {
        home = { 
        username = "root"; # Dynamisch op basis van de huidige gebruiker
        homeDirectory = "/root";
      };
    };

    in {
      inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
         #./home/default.nix
         ./home/zsh.nix
         ./home/vim.nix
         ./home/tmux.nix
         ./home/linux-desktop.nix
         ./home/firefox.nix
         linux-defaults
       ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
  ### LINUX HOMEMANAGER END ROOT

  ## LINUX HOMEMANAGER START ALL

# homeConfigurations."default" = home-manager.lib.homeManagerConfiguration(
#    let
#      system = "x86_64-linux";
#      pkgs = nixpkgs.legacyPackages.${system};
#
#      linux-defaults = {pkgs,config,homeage,...}: {
#        home = { ##MAC
#        homeDirectory = if config.username == "root" then "/root" else "/home/${config.username}"; 
#      };
#    };
#
#    in {
#      inherit pkgs;
#
#        # Specify your home configuration modules here, for example,
#        # the path to your home.nix.
#
#        modules = [
#         #./home/default.nix
#         ./home/linux-desktop.nix
#         ./home/firefox.nix
#         linux-defaults
#       ];
#
#       extraSpecialArgs = {
#          unstable = import unstable { inherit system; config.allowUnfree = true; };
#       };
#
#        # Optionally use extraSpecialArgs
#        # to pass through arguments to home.nix
#
#      });
#
  ### LINUX HOMEMANAGER START WTOORREN
  # defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
  homeConfigurations."wtoorren@linuxdesktop" = home-manager.lib.homeManagerConfiguration(
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [(import ./overlays) (import ./overlays/cooklang.nix)];
      };

      linux-defaults = {pkgs,config,homeage,...}: {
        home = { ##MAC
        homeDirectory = "/home/wtoorren";
      };
    };

    in {
      inherit pkgs;


        # Specify your home configuration modules here, for example,
        # the path to your home.nix.

        modules = [
         #./home/default.nix
         ./home/linux-desktop.nix
         ./home/firefox.nix
         ./home/dotfiles/toggl-secret-wtoorren.nix
         ./home/module/ssh-config_hosts
         ./home/sshkeys.nix
         linux-defaults
       ];

       extraSpecialArgs = {
          unstable = import unstable { inherit system; config.allowUnfree = true; };
       };

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix

      });
      ##wtremove home.username="wtoorren";
  ### LINUX HOMEMANAGER END WTOORREN

  #### LINUX SERVER HOMEMANAGER START
  # defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
  homeConfigurations."wtoorren@linuxserver" = home-manager.lib.homeManagerConfiguration(
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      linux-defaults = {pkgs,config,...}: {
        home = {
          homeDirectory = "/home/wtoorren";
        };
      };

    in {
      inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
         #./home/default.nix
         ./home/linux-server.nix
         linux-defaults
       ];
       extraSpecialArgs = {
          unstable = import unstable { inherit system; config.allowUnfree = true; };
       };

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
  #### LINUX SERVER HOMEMANAGER END

  };
}
