{ pkgs, ... }:

{
  home.packages = [
    pkgs.firefox
    pkgs.bitwarden
  ];

  programs.firefox = {
    enable = true;
    extensions = with pkgs; [
      pkgs.bitwarden
    ];
  };
}

