{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    sensibleOnTop = true;
    newSession = false;
    shortcut = "b";
    historyLimit = 5000;
    plugins = [
      pkgs.tmuxPlugins.urlview
    ];

    extraConfig = ''
      set -s escape-time 10                     # faster command sequences
      set -sg repeat-time 600                   # increase repeat timeout

      set -s focus-events on

      set -g base-index 1           # start windows numbering at 1
      setw -g pane-base-index 1     # make pane numbering consistent with windows

      setw -g automatic-rename off  # rename window to reflect current program
      set -g renumber-windows on    # renumber windows when a window is closed

      set -g set-titles on          # set terminal title

      # START WITH MOUSE MODE ENABLED
      set -g mouse on

    '';
  };
}
