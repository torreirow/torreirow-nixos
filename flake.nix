{
  description = "Wouters super conf";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";  
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";  
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-2305, unstable, nix-darwin }: {
  

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
