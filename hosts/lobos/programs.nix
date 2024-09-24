{config, lib, pkgs,  agenix, toggl-cli, ... }:

{
  environment.systemPackages = with pkgs; [
    agenix
    amazon-ecs-cli
    anki
    appimage-run
    attic-client
    autorandr
    avahi
    aws-nuke
    bitwarden
    bluez
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
    git
    git-remote-codecommit
    glibcLocales
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
    lego
    lf
    libreoffice
    mosh
    mpv
    nerdfonts
    nmap
    openssl
    p3x-onenote
    pandoc
    pinentry-gtk2
    postgresql
    pre-commit
    prowler
    python311
    python311Packages.buienradar
    python311Packages.lxml
    python311Packages.pip
    python311Packages.python-telegram-bot
    python311Packages.pytz
    python311Packages.requests
    python311Packages.toggl-cli
    quarto
    remmina
    retext
    ripgrep
    signal-desktop
    slack
    smplayer
    smug
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
    vlc
    mplayer
    hyprland
];

fonts.packages = with pkgs; [
  open-sans
  google-fonts
];

} 
