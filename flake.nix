{
  description = "Wouters super conf";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";  
    nixpkgs-2305.url = "github:NixOS/nixpkgs/nixos-23.05";  
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-2305, unstable }: {

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
        ];
      };

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

  };
}
