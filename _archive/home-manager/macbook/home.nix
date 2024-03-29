{ config, pkgs, ...  }: 

{
  home = {
    homeDirectory = "/Users/wtoorren";

#    packages = with pkgs; [
#      direnv
#      gh
#      git
#      glow
#      gum
#      htop
#      keychain
#      less
#      lolcat
#      neofetch
#      neovim
#      nix-direnv
#      ookla-speedtest
#      tree
#      zsh
#    ];

    stateVersion = "22.11";
    username = "wtoorren";
  };

#  nixpkgs.config = {
#    allowUnfree = true;
#    allowUnfreePredicate = _: true;
#  };

  programs.home-manager.enable = true;
}
