{config, lib, pkgs,  agenix, ... }:

{
  environment.systemPackages = with pkgs; [
    #    usbguard
    #    usbguard-notifier
    # List packages installed in system profile. To search, run:
    #inputs.agenix.packages.${config.system}.default
    #pkgs.toggl-cli
    #python311.spotify_dl
    #xorg.xrandr
    #zoom-us
    agenix
    amazon-ecs-cli
    anki
    appimage-run
    autorandr
    avahi
    aws-nuke
    bitwarden
    bluez
    certbot
    copilot-cli
    coreutils
    curl
    dig
    displaylink
    file
    freeoffice
    gh
    git
    git-remote-codecommit
    glibcLocales
    gnupg
    gum
    home-manager
    hugo
    inetutils
    jellyfin-ffmpeg
    kdePackages.kcalc
    kdePackages.powerdevil
    lf
    mosh
    mpv
    nmap
    openssl
    p3x-onenote
    pandoc
    pinentry-gtk2
    postgresql
    pre-commit
    prowler
    python311
    python311Packages.pip
    remmina
    retext
    signal-desktop
    slack
    smplayer
    spotdl
    spotify
    sqsh
    ssm-session-manager-plugin
    ssmsh
    super-productivity
    telegram-desktop
    terraform
    terraform-docs
    texliveTeTeX
    tfswitch
    thunderbird
    vim
    vscode
    wget
    whatsapp-for-linux
    whisper
    xclip
    xorg.xbacklight
    yt-dlp
    zip
    zoom-us
   # claws-mail
  # $ nix search wget
  ];
} 