{ config, pkgs, ... }: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    envExtra = ''
      # Set ZSH path for oh-my-zsh
      export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
    '';


    initContent = ''
      # Zet RBW_PROFILE vanuit active-profile als het nog niet gezet is
      if [[ -z "$RBW_PROFILE" && -f "$HOME/.config/rbw/active-profile" ]]; then
        export RBW_PROFILE="$(cat "$HOME/.config/rbw/active-profile")"
      fi

      # Custom completions
      fpath=("$HOME/.zsh/completions" $fpath)
      autoload -Uz compinit
      compinit

      # Force SSH agent to use rbw
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/rbw/ssh-agent-socket"

      # Keep XAUTHORITY in sync with the current Wayland/XWayland session
      if [[ -n "$WAYLAND_DISPLAY" ]]; then
        eval $(systemctl --user show-environment | grep ^XAUTHORITY)
      fi

      # atuin init wordt verzorgd door programs.atuin.enableZshIntegration (home/common.nix)
      export PATH="$HOME/bin:$PATH:/home/wtoorren/data/git/wearetechnative/toortools:/home/wtoorren/data/git/wearetechnative/bmc"
      mkdir -p "$HOME/.terraform.d/plugin-cache" ; export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#484848'

      # Fix Home / End keys (alacritty-direct, tmux, atuin, oh-my-zsh safe)
      for km in emacs viins vicmd; do
        bindkey -M $km '\e[H' beginning-of-line
        bindkey -M $km '\e[F' end-of-line
        bindkey -M $km '\e[1~' beginning-of-line
        bindkey -M $km '\e[4~' end-of-line
      done

      bmc() {
      if [[ "$1" == "profsel" ]]; then
      eval "$(command bmc profsel "$@")"
      else
      command bmc "$@"
      fi
      }

      nixhost() {
      NIXHOST=$(bmc ec2ls | awk -F'│' '/nixhost/{gsub(/ /,"",$2); print $2}')
      if [ -z "$NIXHOST" ]; then
      echo "nixhost not found, check AWS profile"
      else
      bmc ec2connect -u ''${USER} -h $NIXHOST
      fi
      }

      # Wayland display vars bijwerken in tmux (tmux-server start voor Wayland)
      if [[ -n "$TMUX" && -n "$WAYLAND_DISPLAY" ]]; then
        tmux setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY"
        tmux setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR"
      fi

      rbwsel() {
        local config_dir="$HOME/.config"
        local active_file="$config_dir/rbw/active-profile"
        local -a profiles=()

        # Default profiel (lege RBW_PROFILE)
        [[ -d "$config_dir/rbw" ]] && profiles+=("(default)")

        # Benoemde profielen: rbw-<naam> directories
        for dir in "$config_dir"/rbw-*/; do
          [[ -d "$dir" ]] || continue
          local name="''${dir%/}"
          name="''${name##*/rbw-}"
          profiles+=("$name")
        done

        if [[ ''${#profiles[@]} -eq 0 ]]; then
          echo "Geen rbw profielen gevonden in $config_dir" >&2
          return 1
        fi

        local selected
        selected=$(printf '%s\n' "''${profiles[@]}" | gum choose --header "Kies RBW profiel")
        [[ -z "$selected" ]] && return 0

        local profile=""
        [[ "$selected" != "(default)" ]] && profile="$selected"

        echo "$profile" > "$active_file"
        export RBW_PROFILE="$profile"
        tmux setenv RBW_PROFILE "$profile" 2>/dev/null || true
        echo "RBW profiel: ''${profile:-(default)}"
      }
    '';

      shellAliases = {
          #aws-switch=". $HOME/data/git/wearetechnative/bmc/aws-profile-select.sh";
          #tfapply="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfapply.sh";
          #tfbackend="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfbackend.sh";
          #tfplan="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfplan.sh";
          aider="/run/keys/wouter/aider";
          view="vi -R";
          walker-reset="pkill -9 elephant; sleep 0.5; uwsm app -- elephant &";
          aws-switch="bmc profsel";
          boostmic="pactl set-source-volume 2 190%";
          micfix="wpctl set-volume @DEFAULT_SOURCE@ 1.05 && echo 'Sandberg microfoon volume hersteld naar 1.05'";
          gbdel=" echo Removing branches from git repo: $(basename -s .git \"$(git config --get remote.origin.url)\"); for branch in $(git branch --format=\"%(refname:short)\" | grep -Ev '^(main|master)$'); do echo -n \"Verwijder branch '$branch'? (y/n) \";  read answer ;  [[ $answer == \"y\" ]] && git branch -D \"$branch\"; done";
          ghrmbranch="for branch in $(git branch |grep -v -i -e main -e master); do git branch -D $branch; done";
          mcsjsonsync="systemctl --user start aws-accounts-sync.service";
          qdm="cd ./output; qdm=$(gum choose $(ls -t *.html ; echo none| head -5)); if [[ $qdm != 'none' ]]; then firefox --new-tab $qdm 2>/dev/null;fi";
          smg="smug $(basename -s \".yml\" $(gum filter  $(ls ~/.config/smug/*.yml)))";
          tfapply="$HOME/data/git/wearetechnative/race/tfapply.sh";
          tfbackend="$HOME/data/git/wearetechnative/race/tfbackend.sh";
          tfplan="$HOME/data/git/wearetechnative/race/tfplan.sh";
          tfswitch="tfswitch -b $HOME/bin/terraform";
          tfunlock="terraform force-unlock -force ";
          vpnkarconnect="openvpn3 session-start --config $HOME/.config/openvpn/lobos.ovpn";
          vpnkardisconnect="openvpn3 session-manage --disconnect --config $HOME/.config/openvpn/lobos.ovpn";
          t="tmux -L default attach -t main";
        };


        oh-my-zsh = {
          enable = true;
          theme = "wouter";
          custom = "${config.home.homeDirectory}/.ohmyzsh-wouter";
        #theme = "gnzh";
        plugins = [
          "git" "z" "kubectl" "emoji" "encode64" "aws" "terraform"
        ];
        #customPkgs = with pkgs; [                                                                                                                      
        #  nix-zsh-completions                                                                                                                          
        #];
      };
    };

  }
