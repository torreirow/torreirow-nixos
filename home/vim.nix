{config,pkgs,...}: {

  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      source ~/.vimrc
    '';
  };

  # Wayland clipboard support for vim
  home.packages = with pkgs; [
    wl-clipboard  # Provides wl-copy and wl-paste for Wayland clipboard access
  ];
} 
