{ config, pkgs,... }:

{

   inputs.toggl-cli.url = "github:AuHau/toggl-cli";

  # optional, not necessary for the module
  #inputs.toggl-cli.inputs.nixpkgs.follows = "nixpkgs";
  # optionally choose not to download darwin deps (saves some resources on Linux)
  #inputs.toggl-cli.inputs.darwin.follows = "";

  outputs = { self, nixpkgs, toggl-cli }: {
    # change `yourhostname` to your actual hostname
    nixosConfigurations.lobos = nixpkgs.lib.nixosSystem {
      # change to your system:
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        toggl.nixosModules.default
      ];
    };
  };

}
