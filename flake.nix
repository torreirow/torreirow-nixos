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
      url = "git+ssh://git@github.com/torreirow/nixvim";
      inputs.nixpkgs.follows = "unstable";
    };
    #bmc.url = "github:wearetechnative/bmc?rev=3cfa158a5a622df59686537c68b256ecb4bff74c";
    race.url = "github:wearetechnative/race";
    brigit.url = "github:wearetechnative/brigit";
    jsonify-aws-dotfiles.url = "github:wearetechnative/jsonify-aws-dotfiles";
    dirty-repo-scanner.url = "github:mipmip/dirty-repo-scanner";
    openspec.url = "github:Fission-AI/OpenSpec";
    parsh.url = "github:torreirow/parsh";
    linny-web.url = "github:torreirow/linny-web-theme";
    linny-mcp.url = "github:linden-project/linny-mcp-server";
    linny-mcp.inputs.nixpkgs.follows = "nixpkgs";
    specgetty.url = "github:mipmip/specgetty";
    soltty.url = "github:torreirow/soltty";
    ragenx.url = "github:torreirow/ragenx/v0.2.0";
    ragenx.inputs.nixpkgs.follows = "nixpkgs";
    rbw.url = "github:torreirow/rbw";
    rme.url = "github:mipmip/rme";
    huphop.url = "github:mipmip/huphop";
    lif.url = "github:rierek/lif";
    solidtime-waybar.url = "github:torreirow/solidtime-waybar";
    hyprquickframe = {
      url = "github:torreirow/HyprQuickFrame";
      inputs.nixpkgs.follows = "unstable";
    };
    walker.url = "github:abenz1267/walker";
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



  outputs = inputs@{ self, nixpkgs, unstable, home-manager, agenix, nixvim, bmc, homeage, dirty-repo-scanner, race, brigit, jsonify-aws-dotfiles, nixpkgs-2505, nixpkgs-2511, nixpkgs-luca, openspec, teejay, parsh, specgetty, soltty, ragenx, rme, walker, solidtime-waybar, hyprquickframe, rbw, linny-web, linny-mcp, huphop, lif}:
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
        ragenx.packages."${system}".default
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
        defaults = { pkgs, ... }: {
          nixpkgs.overlays = [
            (final: prev: { rbw = inputs.rbw.packages.${system}.rbw; })
            (import ./overlays)
            (import ./overlays/cooklang.nix)
            (import ./overlays/hyprlock.nix)
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
        { environment.systemPackages = [ huphop.packages.${system}.default ]; }
        ./modules/tnaws.nix
        ./modules/jiratui.nix
      ];
    };
### LOBOS config END
### MALANDRO config START
  nixosConfigurations.malandro = nixpkgs.lib.nixosSystem {
    modules =
      let
        defaults = { pkgs, ... }: {
          nixpkgs.overlays = [
            (final: prev: { rbw = inputs.rbw.packages.${system}.rbw; })
            (import ./overlays)
            inputs.linny-mcp.overlays.default
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
        inputs.linny-web.nixosModules.linny-web
        inputs.linny-mcp.nixosModules.linny-mcp
        # Immich uit unstable (3.x): 26.05 heeft alleen 2.7.5, dat geen updates meer krijgt
        # en als insecure gemarkeerd is. Module en pakket komen samen uit dezelfde input.
        {
          disabledModules = [ "services/web-apps/immich.nix" ];
          imports = [ "${unstable}/nixos/modules/services/web-apps/immich.nix" ];
        }
        ./hosts/malandro/configuration.nix
        ./modules/tnaws.nix
      ];
    };
### MALANDRO config END


  ## MPENZI config START
  # Laptop van Maaike: kaal host-blok, geen extraPkgs/overlays (zie docs/mpenzi.md). Wouter
  # krijgt home-manager via wtoorren-admin (dat ook de HM-module importeert), Maaike alleen voor
  # app-standaarden via modules/maaike-apps.nix (in hosts/mpenzi/configuration.nix).
  nixosConfigurations.mpenzi = nixpkgs.lib.nixosSystem {
    modules =
      let
        defaults = { pkgs, ... }: {
          _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
        };
      in [
        defaults
        agenix.nixosModules.default
        (import ./modules/wtoorren-admin.nix { inherit home-manager nixvim bmc race; })
        ./hosts/mpenzi/configuration.nix
      ];
    };
### MPENZI config END

  ### LINUX HOMEMANAGER START ROOT
  homeConfigurations."root@linuxdesktop" = home-manager.lib.homeManagerConfiguration(
    let
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
         ./home/linux-root.nix
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
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [(final: prev: { rbw = inputs.rbw.packages.${system}.rbw; }) (import ./overlays) (import ./overlays/cooklang.nix) (import ./overlays/wayle.nix) (import ./overlays/hyprlock.nix)];
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
         ./home/module/remarkable-sync
         ./home/module/notify-signal
         ./home/module/jitsi-open-in-app
         ./home/module/meeting-record
         ./home/module/linny-mcp-tunnel
         ./home/module/update-system
         ./home/module/clipbridge
         ./home/sshkeys.nix
         ./home/module/opencode.nix
         ./home/module/onlyoffice-fonts.nix
         ./home/hyprland/default.nix
         nixvim.homeModules.default
         { home.packages = [ lif.packages.${system}.default ]; }
         linux-defaults
       ];

       extraSpecialArgs = {
          unstable = import unstable { inherit system; config.allowUnfree = true; };
          walker-input = walker;
          solidtime-waybar-input = solidtime-waybar;
          hyprquickframe-input = hyprquickframe;
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
         { home.packages = [ lif.packages.${system}.default ]; }
         linux-defaults
       ];
       extraSpecialArgs = {
          unstable = import unstable { inherit system; config.allowUnfree = true; };
       };

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      });
  #### LINUX SERVER HOMEMANAGER END

  #### WTOORREN-ADMIN HOMEMANAGER START
  # wtoorren-admin standalone, voor niet-NixOS-hosts (nixhost):
  #   home-manager switch --flake .#wtoorren@admin -b backup
  # NixOS-hosts gebruiken modules/wtoorren-admin.nix. Zie docs/wtoorren-admin.md.
  homeConfigurations."wtoorren@admin" = home-manager.lib.homeManagerConfiguration (
    {
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
      modules = [
        ./home/profiles/wtoorren-admin
        # Lichte nixvim (zonder LSP/linters/dap); wtoorren@linuxdesktop houdt de volledige.
        nixvim.homeModules.light
        {
          home.username = "wtoorren";
          home.homeDirectory = "/home/wtoorren";
          # Zelfde als wtoorren@linuxserver, waar nixhost vandaan komt.
          home.stateVersion = "25.11";
          programs.home-manager.enable = true;
          targets.genericLinux.enable = true;
        }
      ];
      extraSpecialArgs = {
        unstable = import unstable { inherit system; config.allowUnfree = true; };
        adminInputs = { inherit bmc race; };
      };
    });
  #### WTOORREN-ADMIN HOMEMANAGER END

  # VM-tests: nix build .#checks.x86_64-linux.<naam> -L
  checks.x86_64-linux.grainwork =
    nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
      imports = [ ./modules/grainwork_vmtest.nix ];
      # De module declareert age.secrets (ook als agenix = false); de optie moet bestaan.
      defaults.imports = [ agenix.nixosModules.default ];
    };

  # wtoorren-admin: zsh-login, AWS-wrappers alleen met credentials, SSH_AUTH_SOCK per sessie.
  checks.x86_64-linux.wtoorren-admin =
    nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
      imports = [ ./modules/wtoorren-admin_vmtest.nix ];
      defaults = {
        imports = [ (import ./modules/wtoorren-admin.nix { inherit home-manager nixvim bmc race; }) ];
        _module.args.unstable = import unstable { inherit system; config.allowUnfree = true; };
      };
    };

  # Nebula-mesh: toegangsbeleid lobos/malandro -> mpenzi (modules/nebula.nix).
  # App-standaarden van maaike: seeds en herstel-app (modules/maaike-apps.nix).
  checks.x86_64-linux.maaike-apps =
    nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
      imports = [ ./modules/maaike-apps_vmtest.nix ];
      defaults.imports = [
        home-manager.nixosModules.home-manager
        agenix.nixosModules.default
        ./modules/maaike-apps.nix
      ];
    };

  # Immich: ML-jobs inhalen als lobos terug is (modules/immich-ml-catchup).
  checks.x86_64-linux.immich-ml-catchup =
    nixpkgs.legacyPackages.x86_64-linux.callPackage ./modules/immich-ml-catchup/test.nix { };

  # Immich: VAAPI-patch (format=nv12 vóór hwupload, modules/immich-vaapi-patch.nix).
  checks.x86_64-linux.immich-vaapi-patch =
    let u = import unstable { inherit system; config.allowUnfree = true; };
    in u.callPackage ./modules/immich-vaapi-patch_test.nix { };

  # Podcast op mpenzi: podrec-script met nep-PipeWire (modules/podcast-opname).
  checks.x86_64-linux.podrec =
    nixpkgs.legacyPackages.x86_64-linux.callPackage ./modules/podcast-opname/test.nix { };

  # Podcast op mpenzi: namen per poort, stereobron, ALSA-apparaat en podrec met snd-aloop.
  checks.x86_64-linux.podcast-opname =
    nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
      imports = [ ./modules/podcast-opname/vmtest.nix ];
    };

  checks.x86_64-linux.nebula =
    nixpkgs.legacyPackages.x86_64-linux.testers.runNixOSTest {
      imports = [ ./modules/nebula_vmtest.nix ];
      defaults.imports = [ agenix.nixosModules.default ];
    };

  };
}
