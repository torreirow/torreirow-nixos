{ config,pkgs,inputs,...}:
{
      environment.systemPackages =
        [ pkgs.vim
          pkgs.docker
          pkgs.docker-compose
        ];

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      nix.nixPath = [
            "nixpkgs=${inputs.nixpkgs}"
            "darwin=${inputs.nix-darwin}"
          ];

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      # programs.fish.enable = true;

      security.pam.enableSudoTouchIdAuth = true;
      nix.extraOptions = ''
      extra-platforms = x86_64-darwin aarch64-darwin
      '';

      # Set Git commit hash for darwin-version.
      #system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 4;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      nix.linux-builder.enable = true;
      # Add user to trusted-users
      nix.settings.trusted-users = [ "wtoorren" "@staff" "root" ];
}
