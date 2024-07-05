{ config, pkgs,... }:

{

   inputs.agenix.url = "github:ryantm/agenix";
  # optional, not necessary for the module
  #inputs.agenix.inputs.nixpkgs.follows = "nixpkgs";
  # optionally choose not to download darwin deps (saves some resources on Linux)
  #inputs.agenix.inputs.darwin.follows = "";

  outputs = { self, nixpkgs, agenix }: {
    # change `yourhostname` to your actual hostname
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      # change to your system:
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        agenix.nixosModules.default
      ];
    };
  };

}
