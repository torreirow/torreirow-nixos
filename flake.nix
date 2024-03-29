{
  description = "Wouters super conf";

  inputs = {
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


  outputs = inputs@{ self, nixpkgs, nixpkgs-2305, unstable, nix-darwin, home-manager }: {
  
### MEALHADA HOMEMANAGER START
     defaultPackage.aarch64-darwin = home-manager.defaultPackage.aarch64-darwin;
     homeConfigurations."wtoorren@macbook" = home-manager.lib.homeManagerConfiguration(
      let
       system = "aarch64-darwin";
       pkgs = nixpkgs.legacyPackages.${system};
       mac-defaults = {pkgs,config,...}: {
        home = { ##MAC
         homeDirectory = "/Users/wtoorren";
         stateVersion = "23.11";
         username = "wtoorren";
        };
       };

      in {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ 
         #( import ./home/default.nix ) 
         ./home/default.nix
         mac-defaults
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
### MEALHADA HOMEMANAGER START
	#homeConfigurations = {
        #    "wtoorren" = home-manager.lib.homeManagerConfiguration {
        #        # Note: I am sure this could be done better with flake-utils or something
        #        pkgs = import nixpkgs { system = "aarch64-darwin"; };
        #        modules = [ ./home/default.nix ]; 
        #    };
        #};

### MEALHADA config START
    darwinConfigurations."mealhada" = nix-darwin.lib.darwinSystem {
    specialArgs = { inherit inputs; } ;
      modules = [ 
       ./hosts/mealhada/configuration.nix
       ./modules/tnaws.nix
      ];
    };

    darwinPackages = self.darwinConfigurations."mealhada".pkgs;
### MEALHADA config END





### KARLAPI config START
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

  };
}
