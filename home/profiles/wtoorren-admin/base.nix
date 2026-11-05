# Basis van het wtoorren-admin-profiel: zsh, tmux, rbw en de shell-hulpmiddelen. Bronbestanden
# (oh-my-zsh-thema, completions, rbw-configs) komen uit home/dotfiles, gedeeld met lobos/malandro.
{ config, lib, pkgs, ... }:

let
  dotfiles = ../../dotfiles;
in
{
  imports = [
    ../../tmux.nix
    ../../shell-tools.nix
  ];

  programs.rbw.enable = true;

  home.file = {
    # Twee rbw-profielen: toorren (default) en technative (RBW_PROFILE=technative).
    ".config/rbw/config.json".source = dotfiles + "/.config/rbw/config.json";
    ".config/rbw-technative/config.json".source = dotfiles + "/.config/rbw-technative/config.json";
    ".ohmyzsh-wouter" = {
      source = dotfiles + "/.ohmyzsh-wouter";
      recursive = true;
    };
    ".zsh/completions" = {
      source = dotfiles + "/.zsh/completions";
      recursive = true;
    };
  };

  home.packages = with pkgs; [
    # De rbw-configs noemen `pinentry-tty`; op niet-NixOS staat die nergens anders in PATH.
    pinentry-tty
    gum # rbwsel
  ];

  home.sessionVariables.LANG = "en_US.UTF-8";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    envExtra = ''
      export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
    '';

    initContent = ''
      # RBW_PROFILE uit active-profile, als dat bestand er is (rbwsel maakt het aan).
      if [[ -z "$RBW_PROFILE" && -f "$HOME/.config/rbw/active-profile" ]]; then
        export RBW_PROFILE="$(cat "$HOME/.config/rbw/active-profile")"
      fi

      fpath=("$HOME/.zsh/completions" $fpath)
      autoload -Uz compinit
      compinit

      # rbw-agent als SSH-agent, behalve in een ssh-sessie: daar blijft de doorgestuurde agent
      # (ssh -A) staan.
      if [[ -z "$SSH_CONNECTION" ]]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/rbw/ssh-agent-socket"
      fi

      export PATH="$HOME/bin:$PATH"
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#484848'

      # Home / End in tmux, atuin en oh-my-zsh
      for km in emacs viins vicmd; do
        bindkey -M $km '\e[H' beginning-of-line
        bindkey -M $km '\e[F' end-of-line
        bindkey -M $km '\e[1~' beginning-of-line
        bindkey -M $km '\e[4~' end-of-line
      done

      ${import ../../zsh-rbwsel.nix}
    '';

    shellAliases = {
      view = "vi -R";
      t = "tmux -L default attach -t main";
    };

    oh-my-zsh = {
      enable = true;
      theme = "wouter";
      custom = "${config.home.homeDirectory}/.ohmyzsh-wouter";
      plugins = [ "git" "z" "aws" "terraform" ];
    };
  };
}
