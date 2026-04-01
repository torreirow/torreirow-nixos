{ config, pkgs, ... }:

{
  nixpkgs.overlays = [
    # Atuin overlay - custom version from GitHub
    (self: super: {
      atuin = super.atuin.overrideAttrs (old: rec {
        version = "v18.13.5";

        src = super.fetchFromGitHub {
          owner = "atuinsh";
          repo = "atuin";
          rev = "${version}";
          hash = "sha256-N/s1flB+s2HwEeLsf7YlJG+5TJgP8Wu7PHNPWmVfpIo=";
        };

        cargoDeps = super.rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
        };
      });
    })
  ];
}
