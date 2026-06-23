{
  description = "Wouters super conf";

  inputs = {
    agenix.url = "github:ryantm/agenix";
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-26.05";
    nixpkgs-2511.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-luca.url = "github:Caspersonn/nixpkgs";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    teejay.url = "github:mipmip/teejay";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    bmc.url = "github:wearetechnative/bmc";
    nixvim = {
      url = "path:/home/wtoorren/data/git/torreirow/nixvim";
      inputs.nixpkgs.follows = "unstable";
    };
    #bmc.url = "github:wearetechnative/bmc?rev=3cfa158a5a622df59686537c68b256ecb4bff74c";
    race.url = "github:wearetechnative/race";
    brigit.url = "github:wearetechnative/brigit";
    jsonify-aws-dotfiles.url = "github:wearetechnative/jsonify-aws-dotfiles";
    dirty-repo-scanner.url = "github:mipmip/dirty-repo-scanner";
    openspec.url = "github:Fission-AI/OpenSpec";
    parsh.url = "github:torreirow/parsh";
    specgetty.url = "github:mipmip/specgetty";
    soltty.url = "github:torreirow/soltty";
    rme.url = "github:mipmip/rme";
    solidtime-waybar.url = "github:torreirow/solidtime-waybar";
    walker.url = "github:abenz1267/walker";
    hyprswitch.url = "github:h3rmt/hyprswitch";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homeage = {
      url = "github:jordanisaacs/homeage";
      # Optional
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };



  outputs = inputs@{ self, nixpkgs, unstable, home-manager, agenix, nixvim, bmc, homeage, dirty-repo-scanner, race, brigit, jsonify-aws-dotfiles, nixpkgs-2505, nixpkgs-2511, nixpkgs-luca, openspec, teejay, parsh, specgetty, soltty, rme, walker, solidtime-waybar, hyprswitch}:
  let 
    system = "x86_64-linux";
    extraPkgs= { pkgs, ...}: {
      environment.systemPackages = [
        bmc.packages."${system}".bmc
        dirty-repo-scanner.packages."${system}".dirty-repo-scanner
        race.packages."${system}".race
        brigit.packages."${system}".brigit
        jsonify-aws-dotfiles.packages."${system}".jsonify-aws-dotfiles
        openspec.packages."${system}".default
        parsh.packages."${system}".default
        specgetty.packages."${system}".specgetty
        soltty.packages."${system}".soltty
        rme.packages."${system}".rme
        teejay.packages."${system}".default
      ];
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
          nixpkgs.overlays = [
            (import ./overlays)
            (import ./overlays/cooklang.nix)
            (final: prev:
              let
                pandoc-3_8_3 = prev.stdenv.mkDerivation {
                  pname = "pandoc";
                  version = "3.8.3";
                  src = prev.fetchurl {
                    url = "https://github.com/jgm/pandoc/releases/download/3.8.3/pandoc-3.8.3-linux-amd64.tar.gz";
                    hash = "sha256-wiT6uJ+CfTYjOA7LfBB4wWPHachJoUrCfo07+7kUybQ=";
                  };
                  nativeBuildInputs = [ prev.autoPatchelfHook ];
                  buildInputs = [ prev.gmp prev.libffi prev.zlib prev.stdenv.cc.cc.lib ];
                  dontBuild = true;
                  installPhase = ''
                    mkdir -p $out/bin
                    cp bin/pandoc $out/bin/
                  '';
                  meta.mainProgram = "pandoc";
                };
                quarto-base = prev.quarto.override {
                  pandoc = pandoc-3_8_3;
                  extraRPackages = [ prev.rPackages.reticulate ];
                  extraPythonPackages = ps: with ps; [
                    plotly numpy pandas matplotlib tabulate
                  ];
                };
              in {
                quarto = quarto-base.overrideAttrs (_: {
                  version = "1.9.38";
                  src = prev.fetchurl {
                    url = "https://github.com/quarto-dev/quarto-cli/releases/download/v1.9.38/quarto-1.9.38-linux-amd64.tar.gz";
                    hash = "sha256-6oyJc2h5GtnyAAEMCH6jERsuVWsSqWBIfdTiFpAqoQI=";
                  };
                });
              }
            )
          ];
          _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2511 = import nixpkgs-2511 { inherit system; config.allowUnfree = true; };
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
          nixpkgs.overlays = [
            (import ./overlays)
            (final: prev:
              let
                pandoc-3_8_3 = prev.stdenv.mkDerivation {
                  pname = "pandoc";
                  version = "3.8.3";
                  src = prev.fetchurl {
                    url = "https://github.com/jgm/pandoc/releases/download/3.8.3/pandoc-3.8.3-linux-amd64.tar.gz";
                    hash = "sha256-wiT6uJ+CfTYjOA7LfBB4wWPHachJoUrCfo07+7kUybQ=";
                  };
                  nativeBuildInputs = [ prev.autoPatchelfHook ];
                  buildInputs = [ prev.gmp prev.libffi prev.zlib prev.stdenv.cc.cc.lib ];
                  dontBuild = true;
                  installPhase = ''
                    mkdir -p $out/bin
                    cp bin/pandoc $out/bin/
                  '';
                  meta.mainProgram = "pandoc";
                };
                quarto-base = prev.quarto.override {
                  pandoc = pandoc-3_8_3;
                  extraRPackages = [ prev.rPackages.reticulate ];
                  extraPythonPackages = ps: with ps; [
                    plotly numpy pandas matplotlib tabulate
                  ];
                };
              in {
                quarto = quarto-base.overrideAttrs (_: {
                  version = "1.9.38";
                  src = prev.fetchurl {
                    url = "https://github.com/quarto-dev/quarto-cli/releases/download/v1.9.38/quarto-1.9.38-linux-amd64.tar.gz";
                    hash = "sha256-6oyJc2h5GtnyAAEMCH6jERsuVWsSqWBIfdTiFpAqoQI=";
                  };
                });
              }
            )
          ];
          _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2505 = import nixpkgs-2505 { inherit system; config.allowUnfree = true; };
          _module.args.pkgs-2511 = import nixpkgs-2511 { inherit system; config.allowUnfree = true; };
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
         nixvim.homeModules.default
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
         ./home/module/ssh-config_hosts
         ./home/sshkeys.nix
         ./home/module/opencode.nix
         ./home/hyprland/default.nix
         nixvim.homeModules.default
         linux-defaults
       ];

       extraSpecialArgs = {
          unstable = import unstable { inherit system; config.allowUnfree = true; };
          walker-input = walker;
          solidtime-waybar-input = solidtime-waybar;
          hyprswitch-input = hyprswitch;
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
         nixvim.homeModules.default
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
