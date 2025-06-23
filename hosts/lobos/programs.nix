{config, unstable, lib, pkgs,  pkgs-luca, agenix, toggl-cli, ... }:

{
  
  environment.systemPackages = with pkgs; [
    #bluez
    #cooklang
    #flameshot
    agenix
    alacritty
    amazon-ecs-cli
    appimage-run
    atomix # puzzle game
    attic-client
    autorandr
    avahi
    aws-nuke
    awscli2
    bitwarden
    caligula
    catppuccin
    clementine
    certbot
    cheese # webcam tool
    copilot-cli
    coreutils
    cowsay
    csvkit
    curl
    dig
    digikam
    displaylink
    entr
    epiphany # web browser
    exiftool
    ffmpeg-full
    file
    fwupd
    fwupd-efi
    gcc
    geary # email reader
    gh
    gimp
    git
    git-remote-codecommit
    git-sync
    glibcLocales
    gnome-initial-setup
    gnome-music
    gnupg
    go
    go-mtpfs
    granted
    gum
    hitori # sudoku game
    home-assistant-component-tests.buienradar
    home-manager
    hugo
    iagno # go game
    inetutils
    kdePackages.kcalc
    kdePackages.powerdevil
    kitty
    lego
    lf
    libreoffice
    librewolf
    librewolf-unwrapped
    librsvg
    lua
    mosh
    mplayer
    mpv
    neovim
    nerdfetch
    nmap
    openai-whisper
    openssl
    p3x-onenote
    pandoc
    pavucontrol
    pinentry-gtk2
    postgresql
    pre-commit
    prowler
    qemu
    qogir-theme
    quarto
    redis
    remmina
    ripgrep
    ripgrep
    ruby
    scrot
    seahorse
    signal-desktop
    silver-searcher
    slack
    smplayer
    smug
    soco-cli
    spotdl
    spotify
    sqlite
    sqsh
    ssm-session-manager-plugin
    ssmsh
    subtitleedit
    super-productivity
    tali # poker game
    teams-for-linux
    telegram-desktop
    terraform
    terraform-docs
    tfswitch
    thunderbird
    tmuxPlugins.catppuccin
    translate-shell
    unstable.aider-chat-full
    vista-fonts
    vlc
    vscode
    wget
    whatsapp-for-linux
    zapzap
    xclip
    xorg.xbacklight
    yelp # Help view
    yj
    yq
    yt-dlp
    zip
    zoom-us
   # jellyfin-ffmpeg
#    gnome.gnome-tweaks
(texlive.combine {
  inherit (texlive) scheme-full datetime fmtcount textpos makecell lipsum footmisc background ; 
})
    #texliveFull
    #texlivePackages.datetime
    #texlivePackages.svg
    #texlivePackages.fmtcount
#    pkgs-luca.quiqr
xdg-desktop-portal
  ] ;


#fonts.packages = with pkgs; [
#  open-sans
#  google-fonts
#];



}
