{config, unstable, lib, pkgs, pkgs-luca, agenix, ... }:

{
programs.ssh = {
  enableAskPassword = false;
  askPassword = null;
};
environment.systemPackages = with pkgs; [
    planify
    wineWow64Packages.stable
    # masterpdfeditor  # TEMP disabled: upstream 5.9.98 tarball 404s in pinned nixpkgs (re-enable after nixpkgs bump)
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    R
    unstable.beans
    gnome-network-displays
    rPackages.knitr
    rPackages.rmarkdown
    rPackages.ggplot2
    rPackages.dplyr
    rPackages.patchwork
    claude-code
    onlyoffice-desktopeditors
    firefox
    lsb-release
    osv-scanner
    desktop-file-utils
    dstp
    android-tools   # adb (uaccess-regels via systemd 258, geen programs.adb meer nodig)
    perl
    karere
    #bluez
    #cooklang
    #flameshot
    openai
    unstable.lynis
    fastfetch
    go-mtpfs
    direnv
    agenix
    alacritty
    attic-client
    avahi
    aws-nuke
    awscli2
    #bitwarden-desktop # tijdelijk uitgeschakeld - nixpkgs build broken (commercial-sdk-internal npm fetch error)
    caligula
    catppuccin
    unstable.strawberry  # Replaced Clementine - better maintained, native Wayland support
    certbot
    cheese # webcam tool
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
    simple-mtpfs
    mtpfs
    libmtp
    granted
    gum
    hitori # sudoku game
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
    #librewolf
    #librewolf-unwrapped
    librsvg
    lua
    mosh
    mplayer
    mpv
    # nixvim wordt toegevoegd via extraPkgs in flake.nix
    nerdfetch
    nmap
    openai-whisper
    openssl
    pandoc
    pavucontrol
    #pinentry-gtk2
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
    # ssmsh wordt toegevoegd via extraPkgs in flake.nix (flake input torreirow/ssmsh)
    unstable.subtitleedit
    tali # poker game
    teams-for-linux
    telegram-desktop
    terraform
    terraform-docs
    tfswitch
    thunderbird
    tmuxPlugins.catppuccin
    translate-shell
#    unstable.aider-chat-full
    vista-fonts
    vlc
    wget
    zapzap
    xclip
    autocutsel
    xbacklight
    yelp # Help view
    yj
    yq
    yt-dlp
    zip
    zoom-us
    jitsi-meet-electron   # desktop-app (client), niet de server-module
    # Nix dev & security tools
    deadnix
    nixfmt
    nixpkgs-fmt
    statix
    shellcheck
    tflint
    tfsec
    vulnix
    sbctl
    sbomnix
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

programs.nix-ld = {
    enable = true;

    libraries = with pkgs; [
      # C/C++ runtime
      stdenv.cc.cc

      # Core GLib/GObject/GIO
      glib
      dbus

      # GTK stack
      gtk3
      atk
      at-spi2-core
      at-spi2-atk
      gdk-pixbuf
      pango
      cairo

      # Audio
      alsa-lib

      # Printing (needed by Electron)
      cups

      # Crypto/Networking
      nss
      nspr
      nssTools

      # Fonts
      fontconfig
      freetype
      expat

      # Graphics & GPU
      mesa
      libdrm
      libglvnd
      libgbm

    ] ++ (with pkgs; [
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcursor
      libxi
      libxrender
      libxcb
      libxkbcommon
    ]);
  };

#fonts.packages = with pkgs; [
#  open-sans
#  google-fonts
#];

 programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
    flake = "/home/wtoorren/data/git/torreirow/torreirow-nixos"; # sets NH_OS_FLAKE variable for you
  };




}
