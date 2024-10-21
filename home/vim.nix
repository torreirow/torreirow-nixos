{config,pkgs,...}: {

  programs.vim = {
    enable = true;
    defaultEditor = true;
    extraConfig = ''
      source ~/.vimrc
    '';
  };
} 
