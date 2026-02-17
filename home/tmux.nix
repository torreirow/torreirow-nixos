{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    clock24 = true;

    terminal = "xterm-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      gruvbox
    ];

    extraConfig = ''
      ##### Basis #####
      set -g prefix C-a
      unbind C-b
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
      set -g allow-passthrough all
      set -ga terminal-overrides ',xterm-256color:Ms=\E]52;c;%p1%s\007'
      set -as terminal-features ',xterm-256color:clipboard'

      set-window-option -g window-active-style bg=black
      set-window-option -g window-style bg='#141414'

      ##### Statusbar #####
      set -g status-left "#S "
      set -g status-right "#[fg=#a89984]%Y-%m-%d  %H:%M #[fg=#bdae93] #h #[fg=#a89984] ⌨ #{prefix}"

    '';
  };
}

