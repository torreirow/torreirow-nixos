{ config, pkgs, ... }:

{
  # Systemd service om tmux server te starten bij login
  systemd.user.services.tmux = {
    Unit = {
      Description = "tmux server";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.tmux}/bin/tmux new-session -d -A -s main";
      RemainAfterExit = "yes";
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
      set-option -g update-environment "SSH_CLIENT SSH_TTY SSH_CONNECTION"

      # Gebruik C-b voor SSH sessies, C-a voor lokaal
      if-shell '[ -n "$SSH_CONNECTION" ]' \
        'set -g prefix C-b; unbind C-a; bind C-b send-prefix' \
        'set -g prefix C-a; unbind C-b; bind C-a send-prefix'

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

