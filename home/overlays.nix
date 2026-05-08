{ config, pkgs, unstable, ... }:

{
  nixpkgs.overlays = [
    # Atuin overlay - custom version v18.13.5 from GitHub
    # Uses unstable rustPlatform for Rust 1.94.0 support
    (final: prev:
    let
      unstablePkgs = unstable;
    in {
      atuin = unstablePkgs.rustPlatform.buildRustPackage rec {
        pname = "atuin";
        version = "18.13.5";

        src = unstablePkgs.fetchFromGitHub {
          owner = "atuinsh";
          repo = "atuin";
          tag = "v${version}";
          hash = "sha256-XOFD7ZvSejNOrXjcR4jBrjimoWC0oNX7DEPN43ACQpE=";
        };

        # Cargo dependencies hash for v18.13.5
        cargoHash = "sha256-4H57Fm6OnA7TaZTfOZeJhsc2s+hZw/MpWAbgtz+L0C4=";

        # Build configuration
        buildNoDefaultFeatures = true;

        # CRITICAL: Remove "server" feature - it was removed in atuin v18.13.0
        buildFeatures = [ "client" "sync" "clipboard" "daemon" ];

        # Skip tests that require CA certificates
        doCheck = false;

        nativeBuildInputs = [ unstablePkgs.installShellFiles ];

        postInstall = unstablePkgs.lib.optionalString (unstablePkgs.stdenv.buildPlatform.canExecute unstablePkgs.stdenv.hostPlatform) ''
          installShellCompletion --cmd atuin \
            --bash <($out/bin/atuin gen-completions -s bash) \
            --fish <($out/bin/atuin gen-completions -s fish) \
            --zsh <($out/bin/atuin gen-completions -s zsh)
        '';

        meta = with unstablePkgs.lib; {
          description = "Magical shell history";
          homepage = "https://github.com/atuinsh/atuin";
          license = licenses.mit;
          maintainers = with maintainers; [ ];
          mainProgram = "atuin";
        };
      };
    })
  ];
}
