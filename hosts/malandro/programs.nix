{config, unstable, lib, pkgs, pkgs-luca, agenix, ... }:

{
  
  environment.systemPackages = with pkgs; [
    wireguard-tools
    unstable.beans
    #cooklang
    #flameshot
    claude-code
    bluez
    bluez-tools
    agenix
    attic-client
    avahi
    aws-nuke
    awscli2
    caligula
    catppuccin
    certbot
    coreutils
    cowsay
    csvkit
    curl
    dig
    entr
    exiftool
    ffmpeg-full
    file
    fwupd
    fwupd-efi
    gcc
    gh
    gimp
    git
    git-remote-codecommit
    git-sync
    glibcLocales
    gnupg
    go
    go-mtpfs
    granted
    gum
    home-manager
    hugo
    inetutils
    lego
    lf
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
    pinentry-tty
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
    silver-searcher
    smug
    spotdl
    spotify
    sqlite
    sqsh
    ssm-session-manager-plugin
    ssmsh
    # terraform  # Temporarily disabled due to Go compiler ICE
    terraform-docs
    tfswitch
    tmuxPlugins.catppuccin
    translate-shell
    vista-fonts
    vlc
    vscode
    wget
    xclip
    xbacklight
    yelp # Help view
    yj
    yq
    yt-dlp
    zip
    zoom-us
    minica
    acme
    lego
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
