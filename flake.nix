{
  description = "Wouters super conf";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-2311.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    bmc.url = "github:wearetechnative/bmc";
    race.url = "github:wearetechnative/race";
    jsonify-aws-dotfiles.url = "github:wearetechnative/jsonify-aws-dotfiles";
    dirtygit.url = "github:mipmip/dirtygit";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homeage = {
      url = "github:jordanisaacs/homeage";
      # Optional
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };



  outputs = inputs@{ self, nixpkgs, nixpkgs-2305,  nixpkgs-2311, unstable, nix-darwin, home-manager, agenix, bmc, homeage, dirtygit, race, jsonify-aws-dotfiles}: 
  let 
    system = "x86_64-linux";
    extraPkgs= {
      environment.systemPackages = [ 
        bmc.packages."${system}".bmc 
        dirtygit.packages."${system}".dirtygit
        race.packages."${system}".race 
        jsonify-aws-dotfiles.packages."${system}".jsonify-aws-dotfiles
      ];
  };

  in

  {


### MEALHADA HOMEMANAGER START
  #defaultPackage.aarch64-darwin = home-manager.defaultPackage.aarch64-darwin;   ## bootstrap for homemanager
  homeConfigurations."wtoorren@macbook" = home-manager.lib.homeManagerConfiguration(

    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      mac-defaults = {pkgs,config,...}: {
        home = { ##MAC
        homeDirectory = "/Users/wtoorren";
      };
    };

    in {
      inherit pkgs;

    # Specify your home configuration modules here, for example,
    # the path to your home.nix.
    modules = [
         #./home/default.nix
         ./home/linux-desktop.nix
         mac-defaults
       ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
### MEALHADA HOMEMANAGER START

  ## MEALHADA config START
  darwinConfigurations."mealhada" = nix-darwin.lib.darwinSystem {
    specialArgs = { inherit inputs; } ;
    modules = [
      ./hosts/mealhada/configuration.nix
      ./modules/tnaws.nix
    ];
  };
  inputs.
  darwinPackages = self.darwinConfigurations."mealhada".pkgs;
# ## MEALHADA config END


  ## LOBOS config START
  nixosConfigurations.lobos = nixpkgs.lib.nixosSystem {
    modules =
      let
        system = "x86_64-linux";
        defaults = { pkgs, ... }: {
          nixpkgs.overlays = [(import ./overlays)];
          _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2305 = import nixpkgs-2305 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2311 = import nixpkgs-2311 { inherit system; config.allowUnfree = true; };
          _module.args.agenix = inputs.agenix.packages.${system}.default;

        };


        

      in [
        defaults
        extraPkgs
        agenix.nixosModules.default
        ./hosts/lobos/configuration.nix
        ./modules/tnaws.nix
        ./modules/general-desktop.nix
      ];
    };
### LOBOS config END

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
  #     defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
  homeConfigurations."root@linuxdesktop" = home-manager.lib.homeManagerConfiguration(
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      linux-defaults = {pkgs,config,homeage,...}: {
        home = { ##MAC
        homeDirectory = "/root";
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
         linux-defaults
       ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
  ### LINUX HOMEMANAGER END ROOT

  ### LINUX HOMEMANAGER START WTOORREN
  # defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
  homeConfigurations."wtoorren@linuxdesktop" = home-manager.lib.homeManagerConfiguration(
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

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
         linux-defaults
       ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
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

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
  #### LINUX SERVER HOMEMANAGER END

  };
}
