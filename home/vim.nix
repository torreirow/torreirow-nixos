{config,pkgs,...}: {

  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      " Wayland clipboard support
      let g:clipboard = {
        \   'name': 'wl-clipboard',
        \   'copy': {
        \      '+': ['wl-copy'],
        \      '*': ['wl-copy', '--primary'],
        \    },
        \   'paste': {
        \      '+': ['wl-paste', '--no-newline'],
        \      '*': ['wl-paste', '--no-newline', '--primary'],
        \   },
        \   'cache_enabled': 0,
        \ }

      source ~/.vimrc
    '';
  };

  # Wayland clipboard support for vim
  home.packages = with pkgs; [
    wl-clipboard  # Provides wl-copy and wl-paste for Wayland clipboard access
  ];
} 
