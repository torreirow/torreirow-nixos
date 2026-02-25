{config,pkgs,...}: {

  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      " Wayland clipboard support
      if has('wayland_clipboard') || $WAYLAND_DISPLAY != ""
        let g:clipboard = {
          \   'name': 'wl-clipboard',
          \   'copy': {
          \      '+': ['wl-copy', '--foreground', '--type', 'text/plain'],
          \      '*': ['wl-copy', '--foreground', '--primary', '--type', 'text/plain'],
          \    },
          \   'paste': {
          \      '+': ['wl-paste', '--no-newline'],
          \      '*': ['wl-paste', '--no-newline', '--primary'],
          \   },
          \   'cache_enabled': 0,
          \ }
      endif

      source ~/.vimrc
    '';
  };

  # Wayland clipboard support for vim
  home.packages = with pkgs; [
    wl-clipboard  # Provides wl-copy and wl-paste for Wayland clipboard access
  ];
} 
