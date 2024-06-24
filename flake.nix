{
  description = "Wouters super conf";

  inputs = {
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";  
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";  
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";  
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };


  outputs = inputs@{ self, nixpkgs, nixpkgs-2405, nixpkgs-2305, unstable, nix-darwin, home-manager }: {
  
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
  
# ## MEALHADA config START
     darwinConfigurations."mealhada" = nix-darwin.lib.darwinSystem {
     specialArgs = { inherit inputs; } ;
       modules = [ 
        ./hosts/mealhada/configuration.nix
        ./modules/tnaws.nix
       ];
     };
  
     darwinPackages = self.darwinConfigurations."mealhada".pkgs;
# ## MEALHADA config END
 
  
# ## LOBOS config START
     nixosConfigurations.lobos = nixpkgs.lib.nixosSystem {
       modules =
         let
           system = "x86_64-linux";
           defaults = { pkgs, ... }: {
             _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
             _module.args.pkgs-2305 = import nixpkgs-2305 { inherit system; config.allowUnfree = true; };
             _module.args.pkgs-2311 = import nixpkgs-2305 { inherit system; config.allowUnfree = true; };
           };
         in [
           defaults
          ./hosts/lobos/configuration.nix
          ./modules/tnaws.nix
          ./modules/fprint.nix
          ./modules/general-desktop.nix
        ];
      };
### LOBOS config END

#  
# ## KARLAPI config START
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
### LINUX HOMEMANAGER START
#     defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
     homeConfigurations."wtoorren@linuxdesktop" = home-manager.lib.homeManagerConfiguration(
      let
       system = "x86_64-linux";
       pkgs = nixpkgs.legacyPackages.${system};
       linux-defaults = {pkgs,config,...}: {
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
         linux-defaults
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
### MEALHADA HOMEMANAGER END
#### LINUX SERVER HOMEMANAGER START
 #    defaultPackage.x86_64-linux = home-manager.defaultPackage.x86_64-linux;
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
#
 
  };
}
