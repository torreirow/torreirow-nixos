{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.extraOptions = ''
    experimental-features = nix-command
    '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-27bc3389-d74c-4cca-b9ea-64d14a07393a".device = "/dev/disk/by-uuid/27bc3389-d74c-4cca-b9ea-64d14a07393a";
  networking.hostName = "lobos"; # Define your hostname.
#  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # DisplayLink manager + hardware
    boot.extraModulePackages = with config.boot.kernelPackages; [
    evdi
  ];

  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];
  services.xserver.displayManager.sessionCommands = ''
    ${lib.getBin pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource 2 0
    ${lib.getBin pkgs.xorg.xrandr}/bin/xrandr --auto
    '';
      boot.kernelModules = [ "evdi" ];


  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true;

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nl_NL.UTF-8";
    LC_IDENTIFICATION = "nl_NL.UTF-8";
    LC_MEASUREMENT = "nl_NL.UTF-8";
    LC_MONETARY = "nl_NL.UTF-8";
    LC_NAME = "nl_NL.UTF-8";
    LC_NUMERIC = "nl_NL.UTF-8";
    LC_PAPER = "nl_NL.UTF-8";
    LC_TELEPHONE = "nl_NL.UTF-8";
    LC_TIME = "nl_NL.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    # media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wtoorren = {
    isNormalUser = true;
    description = "Wouter van der Toorren";
    extraGroups = [ "networkmanager" "wheel" ];
    # packages = with pkgs; [
    #  thunderbird
    # ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    lf
    slack
    git
    gh
    bitwarden
    home-manager
    terraform
    tfswitch
    vscode
    curl
    dig
    certbot
    python3
    nmap
    ssmsh
    python311Packages.toggl-cli
    ssm-session-manager-plugin
    gum
    inetutils
    openssl
    aws-nuke
    mosh
    postgresql
    zip
    whisper
    jellyfin-ffmpeg
    bluez
    displaylink
    xorg.xrandr
    xorg.xbacklight
    whatsapp-for-linux
    telegram-desktop
    signal-desktop
    freeoffice
    claws-mail
    spotify-player
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
   programs.mtr.enable = true;
#   programs.gnupg.agent = {
#     enable = true;
#     enableSSHSupport = true;
#   };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  environment.etc = {
    "zshrc.local" = {
      text = ''
        PROMPT="%(?:%{$fg_bold[green]%}➜:%{$fg_bold[red]%}➜) %F{magenta}%n%f%{$fg[blue]%}@%M %{$fg[cyan]%}%c%{$reset_color%}"
        PROMPT+=' $(git_prompt_info)'
        ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}(%{$fg[red]%}"
        ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
        ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗"
        ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
      '';
    };
  };

  users.groups.docker.members = [ "wtoorren"  ];

  users.defaultUserShell = pkgs.zsh;
  users.users.root = {
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  virtualisation.docker.enable = true;
}

