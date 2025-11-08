{config, pkgs, ...}:
let
  prefixKey = if builtins.getEnv "HOSTNAME" == "malandro" then "C-a" else "C-b";
in
{
  programs.tmux = {
    enable = true;
    clock24 = true;
    plugins = [
      pkgs.tmuxPlugins.gruvbox
      pkgs.tmuxPlugins.sensible
      pkgs.tmuxPlugins.yank
    ];
    extraConfig = ''
    # prefix based on remote/local
    if -b '[ -n "$SSH_CONNECTION" ]' {
        set -g prefix C-b
      } {
        set -g prefix C-a
      }

    # Plugins
    set -g @plugin 'tmux-plugins/tpm'
    set -g @plugin 'tmux-plugins/tmux-sensible'
    set -g @plugin 'tmux-plugins/tmux-yank'
    set -g @plugin 'tmux-plugins/tmux-resurrect'
    set -g @plugin 'egel/tmux-gruvbox'

    # Basisinstellingen
    set -g prefix C-a
    unbind r
    bind r source-file ~/.config/tmux/tmux.conf \; display-message "Reloaded!"

    set -g mouse on
    set -g base-index 1
    set -g renumber-windows on
    bind-key g set-window-option synchronize-panes \; display-message "synchronize-panes is now #{?pane_synchronized,on,off}"

#    # Gruvbox settings
#    set -g @tmux-gruvbox 'dark'
#    set -g @tmux-gruvbox-statusbar-alpha 'true'

     # catppuccin
     set -g @plugin 'catppuccin/tmux#v2.1.3' # See https://github.com/catppuccin/tmux/tags for additional tags
     set -g @plugin 'tmux-plugins/tpm'
     set -g @catppuccin_flavor 'mocha' # latte, frappe, macchiato or mocha

    # Prefix Highlight stijl (optioneel)
    set -g @prefix_highlight_fg 'black'
    set -g @prefix_highlight_bg 'yellow'


    # Zet statusbar expliciet NA het thema
    set -g status-left '#{prefix_highlight} | #S '

    # TPM loader – moet altijd onderaan staan!
      run '~/.config/tmux/plugins/tpm/tpm'
      set -g status-right '#[bg=default,fg=#504945,nobold,nounderscore,noitalics]#[bg=#504945,fg=#a89984] %Y-%m-%d  %H:%M #[bg=#504945,fg=#bdae93,nobold,noitalics,nounderscore]#[bg=#bdae93,fg=#3c3836] #h #[bg=#504945,fg=#a89984]  ⌨️ #(tmux show-option -gqv prefix) #('

    ''
    ;
  };
}
