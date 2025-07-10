{config, unstable, lib, pkgs,  pkgs-luca, agenix, toggl-cli, ... }:

{
  
  environment.systemPackages = with pkgs; [
    #cooklang
    #flameshot
    caligula
    unstable.aider-chat-full
    scrot
    librewolf
    nerdfetch
    lua
    ripgrep
    librewolf-unwrapped
    redis
    subtitleedit
    translate-shell
    #bluez
    appimage-run
    awscli2
    yq
    gcc
    git-sync
    sqlite
    agenix
    alacritty
    amazon-ecs-cli
    attic-client
    autorandr
    avahi
    aws-nuke
    bitwarden
    certbot
    copilot-cli
    coreutils
    cowsay
    curl
    dig
    digikam
    displaylink
    entr
    exiftool
    file
    fwupd
    fwupd-efi
    gh
    gimp
    git
    git-remote-codecommit
    glibcLocales
    atomix # puzzle game
    cheese # webcam tool
    epiphany # web browser
    geary # email reader
    gnome-initial-setup
    gnome-music
    hitori # sudoku game
    iagno # go game
    seahorse
    tali # poker game
    yelp # Help view
#    gnome.gnome-tweaks
    gnupg
    go
    go-mtpfs
    granted
    gum
    home-assistant-component-tests.buienradar
    home-manager
    hugo
    inetutils
    jellyfin-ffmpeg
    kdePackages.kcalc
    kdePackages.powerdevil
    kitty
    lego
    lf
    libreoffice
    mosh
    mplayer
    mpv
    neovim
    nerdfonts
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
    remmina
    ripgrep
    signal-desktop
    silver-searcher
    slack
    smplayer
    smug
    spotdl
    spotify
    sqsh
    ssm-session-manager-plugin
    ssmsh
    super-productivity
    teams-for-linux
    telegram-desktop
    terraform
    terraform-docs
    tfswitch
    thunderbird
    vlc
    vscode
    wget
    whatsapp-for-linux
    xclip
    xorg.xbacklight
    yj
    yt-dlp
    zip
    zoom-us
    csvkit
    ruby
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
