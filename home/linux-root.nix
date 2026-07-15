{ config, pkgs, ... }: {
  imports = [
    ./zsh.nix
    ./vim.nix
    ./tmux.nix
  ];

  home.file.".ohmyzsh-wouter" = {
    source = ./dotfiles/.ohmyzsh-wouter;
    recursive = true;
  };

  home.stateVersion = "24.05";
}
