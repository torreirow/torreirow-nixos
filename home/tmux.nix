{ config, pkgs, ... }:

let
  beans-tui-popup = pkgs.writeShellScriptBin "beans-tui-popup" ''
    find_project() {
      d="$PWD"
      while [ "$d" != "/" ]; do
        [ -f "$d/.beans.yml" ] && return 0
        d="$(dirname "$d")"
      done
      return 1
    }

    if find_project; then
      beans tui
      rc=$?
      if [ "$rc" -ne 0 ]; then
        echo
        echo "beans tui exited with code $rc"
        echo "---- beans check ----"
        beans check
        echo
        echo "Press any key to close"
        read -rn1
      fi
    else
      echo "No beans project (.beans.yml) found at or above: $PWD"
      echo
      echo "Press any key to close"
      read -rn1
    fi
  '';
in

{
  home.packages = [ beans-tui-popup ];

  # Systemd service om tmux server te starten bij login
  systemd.user.services.tmux = {
    Unit = {
      Description = "tmux server";
      After = [ "default.target" ];
      X-RestartIfChanged = false;
    };
    Service = let tmuxBin = "${pkgs.tmux}/bin/tmux"; in {
      # forking: tmux daemoniseert zichzelf, systemd volgt het server-proces
      # Restart=on-failure: herstart als de server crasht of afsluit
      Type = "forking";
      ExecStart = "${tmuxBin} -L default new-session -d -s main";
      ExecStop = "${tmuxBin} -L default kill-server";
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  programs.tmux = {
    enable = true;
    clock24 = true;

    terminal = "xterm-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      continuum
      gruvbox
    ];

    extraConfig = ''
      ##### Basis #####
      # Update SSH variabelen in tmux environment
      set-option -g update-environment "SSH_CLIENT SSH_TTY SSH_CONNECTION WAYLAND_DISPLAY XDG_RUNTIME_DIR DISPLAY"

      # Gebruik C-b voor SSH sessies, C-a voor lokaal
      if-shell '[ -n "$SSH_CONNECTION" ]' \
        'set -g prefix C-b; unbind C-a; bind C-b send-prefix' \
        'set -g prefix C-a; unbind C-b; bind C-a send-prefix'

      bind T popup -E -w 80% -h 80% 'tj --columns --sort-activity --no-sound --no-notify'
      bind J popup -E -d '#{pane_current_path}' -w 90% -h 90% 'lazyjj'
      bind B popup -E -d '#{pane_current_path}' -w 90% -h 90% 'beans-tui-popup'
      bind C-c popup -E -w 90% -h 90% 'tmux has-session -t cockpit 2>/dev/null || (smug start spg --detach && tmux select-window -t cockpit:spg); TMUX= tmux attach-session -t cockpit'

      unbind r
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Reloaded!"
      set -g mouse on
      set -g base-index 1
      set -g renumber-windows on

      bind-key g set-window-option synchronize-panes \;\
        display-message "synchronize-panes is now #{?pane_synchronized,on,off}"

      ##### Gruvbox #####
      set -g @tmux-gruvbox 'dark'
      set -g @tmux-gruvbox-statusbar-alpha 'true'

      ##### OSC52 / Clipboard #####
      set -g set-clipboard on
      #set -g allow-passthrough all
      set -gq allow-passthrough on
      set -ga terminal-overrides ',xterm-256color:Ms=\E]52;c;%p1%s\007'
      set -as terminal-features ',xterm-256color:clipboard'

      set-window-option -g window-active-style bg=black
      set-window-option -g window-style bg='#141414'

      ##### Statusbar #####
      # Status background
      set -g status-style bg=#282828,fg=#ebdbb2

      # Window status formats (rectangular blocks without arrows)
      set -g window-status-current-format "#[fg=#282828,bg=#fe8019] #I > #W #[bg=#282828] "
      set -g window-status-format "#[fg=#a89984,bg=#3c3836] #I > #W #[bg=#282828] "
      set -g window-status-separator ""

      set -g status-left "#[fg=#282828,bg=#8ec07c] #S #[bg=#282828] "
      set -g status-right "#[fg=#a89984,bg=#282828] %Y-%m-%d  %H:%M #[fg=#3c3836,bg=#282828]#[fg=#ebdbb2,bg=#3c3836] #(if rbw unlocked; then echo '🔓 unlocked'; else echo '🔒 locked'; fi) #[fg=#504945,bg=#3c3836]#[fg=#ebdbb2,bg=#504945] #h #[fg=#fe8019,bg=#504945]#[fg=#282828,bg=#fe8019] ⌨ #{prefix} "

      ##### Resurrect & Continuum #####
      # Herstel vim/nvim sessies
      set -g @resurrect-strategy-vim 'session'
      set -g @resurrect-strategy-nvim 'session'

      # Herstel pane inhoud (optioneel, kan traag zijn)
      set -g @resurrect-capture-pane-contents 'on'

      # Automatisch opslaan elke 15 minuten
      set -g @continuum-save-interval '15'

      # Automatisch herstellen bij tmux start
      set -g @continuum-restore 'on'

      # Toon laatste opslaan tijd in statusbar (optioneel)
      # set -g status-right 'Continuum: #{continuum_status}'
    '';
  };
}

