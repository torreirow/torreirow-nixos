{config, lib, pkgs,  agenix, ... }:


let
  python311 = pkgs.python311;

in

  {
  imports =
    [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./programs.nix
    ./fonts.nix
    ./python.nix
   #./gnome.nix
    ./lobos-secrets.nix
    ../../modules/monitoring
   # ../../modules/teamviewer.nix
    ];



  nix.extraOptions = ''
    experimental-features = nix-command flakes
    '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-27bc3389-d74c-4cca-b9ea-64d14a07393a".device = "/dev/disk/by-uuid/27bc3389-d74c-4cca-b9ea-64d14a07393a";
#  boot.kernelParams = [ "pci=nomsi" "acpi=off" ];
#  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_1;
  boot.supportedFilesystems = [ "ntfs" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];


  services.flatpak.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];
  services.xserver.displayManager.sessionCommands = ''
    #${lib.getBin pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource 2 0
    #${lib.getBin pkgs.xorg.xrandr}/bin/xrandr --auto
    ${lib.getBin pkgs.autorandr}/bin/xrandr --setprovideroutputsource 2 0
    ${lib.getBin pkgs.autorandr}/bin/xrandr --auto
    '';


  ########## NETWORKING ##########
  # Enable networking
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  networking.hostName = "lobos"; # Define your hostname.
  networking.networkmanager = {
    enable = true;
    dhcp = "internal";
    wifi.powersave = false;

  };


  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  ## Spotify discovery devices
  networking.firewall.allowedUDPPorts = [ 5353 ]; # Spotify Connect
  networking.firewall.allowedTCPPorts = [ 57621 22 443 80]; # Sync local tracks

  # Enable bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true;
#  services.blueman.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "nl_NL.UTF-8/UTF-8"
    ];
  };

  environment = {
    sessionVariables = {
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
      SAL_USE_VCLPLUGIN = "gtk3";
      FONTCONFIG_PATH = "/etc/fonts";
    };
  };

   environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "";
    LC_ADDRESS = "nl_NL.UTF-8";
    LC_IDENTIFICATION = "nl_NL.UTF-8";
    LC_MEASUREMENT = "nl.UTF-8";
    LC_MONETARY = "nl_NL.UTF-8";
    LC_NAME = "nl_NL.UTF-8";
    LC_NUMERIC = "nl_NL.UTF-8";
    LC_PAPER = "nl_NL.UTF-8";
    LC_TELEPHONE = "nl_NL.UTF-8";
    LC_TIME = "nl_NL.UTF-8";
  };


environment.variables.EDITOR = "vim";


#  i18n.extraLocaleSettings = {
#    LANG = "nl_NL.UTF-8";
#    LANGUAGE = "en_US.utf8";
#    LC_ADDRESS = "nl_NL.UTF-8";
#    LC_ALL = "en_US.utf8";
#    LC_IDENTIFICATION = "nl_NL.UTF-8";
#    LC_MEASUREMENT = "nl_NL.UTF-8";
#    LC_MONETARY = "nl_NL.UTF-8";
#    LC_NAME = "nl_NL.UTF-8";
#    LC_NUMERIC = "nl_NL.UTF-8";
#    LC_PAPER = "nl_NL.UTF-8";
#    LC_TELEPHONE = "nl_NL.UTF-8";
#    LC_TIME = "nl_NL.UTF-8";
#
#  };
#
  # Enable the X11 windowing system.
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = false;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.plasma5.enable = false;
  services.xserver.desktopManager.gnome.enable = true;

  ## NEW CONFIG
  services.displayManager.defaultSession = "gnome";



## exclude packages
	environment.gnome.excludePackages = (with pkgs; [
			gnome-photos
			gnome-tour
		]) ++ (with pkgs.gnome; [
			#gedit # text editor
			#gnome-characters
			#gnome-contacts
					]);

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

#  # Enable CUPS to print documents.
  services.printing.enable = true;
  #services.printing.drivers = [ pkgs.brlaser ];
  services.printing.browsedConf = ''
  BrowseDNSSDSubTypes _cups,_print
  BrowseLocalProtocols all
  BrowseRemoteProtocols all
  CreateIPPPrinterQueues All
  BrowseProtocols all
    '';

  services.printing.drivers = [ pkgs.cups-dymo ];
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  services.avahi.openFirewall = true;


  services.pulseaudio.enable = false;
 # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wtoorren = {
    isNormalUser = true;
    description = "Wouter van der Toorren";
    extraGroups = [ "networkmanager" "wheel" "keys"];
    # packages = with pkgs; [
    #  thunderbird
    # ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
  services.openssh.extraConfig = "LoginGracetime=0";

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

  programs.gnupg.agent.pinentryPackage = {
   enable = true;
   pinentryFlavor = "gtk2";
 };
  programs.openvpn3 = {
    enable = true;
  };


  age.secrets.secret1.file = ../../secrets/secret1.age;
  age.secretsDir = "/run/keys/wouter";
  users.users.user1 = {
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.secret1.path;
  };

  nix.settings.trusted-public-keys= [
    "cache-key:XR6zauyKza9AMuNDgp7eo91xxCpXaU4D8SKvZw/Mu0Q="
  ];

  nix.settings.trusted-users = [
  "root"
  "wtoorren"
  "@wheel"
];

nixpkgs.config.permittedInsecurePackages = [
    "qtwebkit-5.212.0-alpha"
  ];


## SAMBA START
services.samba = {
  enable = true;
  openFirewall = true;
  settings = {
      global = {
      "workgroup" = "WORKGROUP";
      "server string" = "smbnix";
      "netbios name" = "smbnix";
      "security" = "user";
      #"use sendfile" = "yes";
      #"max protocol" = "smb2";
      # note: localhost is the ipv6 localhost ::1
      "hosts allow" = "192.168.2. 127.0.0.1 localhost";
      "hosts deny" = "0.0.0.0/0";
      "guest account" = "nobody";
      "map to guest" = "bad user";
    };
      "private" = {
      "path" = "/tmp/tmp";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "create mask" = "0644";
      "directory mask" = "0755";
      "force user" = "wtoorren";
      "force group" = "users";
    };
  };
};

services.samba-wsdd = {
  enable = true;
  openFirewall = true;
};

## SAMBA END


services.fwupd.enable = true;
#services.xscreensaver = {
#  enable = true;
#};
#  description = "Restart network services after sleep";
#  wantedBy = [ "sleep.target" "suspend.target" ];
#  before = [ "sleep.target" "suspend.target" ];
#  after = [ "network.target" ];
#  serviceConfig = {
#    Type = "oneshot";
#    ExecStartPre = "/run/current-system/sw/bin/modprobe -r ath11k_pci";
#    ExecStopPost = "/run/current-system/sw/bin/modprobe ath11k_pci";
#    ExecStop = ''
#      /run/current-system/sw/bin/systemctl stop NetworkManager.service systemd-networkd.service systemd-networkd.socket
#    '';
#    ExecStart = ''
#      if /run/current-system/sw/bin/systemctl is-enabled NetworkManager.service; then
#        /run/current-system/sw/bin/systemctl start NetworkManager.service
#      fi
#      if /run/current-system/sw/bin/systemctl is-enabled systemd-networkd.socket; then
#        /run/current-system/sw/bin/systemctl start systemd-networkd.socket
#      fi
#      if /run/current-system/sw/bin/systemctl is-enabled systemd-networkd.service; then
#        /run/current-system/sw/bin/systemctl start systemd-networkd.service
#      fi
#    '';
#  };
#};

networking.wg-quick.interfaces.wg0 = {
    address = [
      "172.27.66.3/24"
    ];
    peers = [
      {
        allowedIPs = [
          "0.0.0.0/0"
        ];
        endpoint = "homeassistant.toorren.net:51820";
        publicKey = "8TLZ86+PygfP3GzrBUiBtXOleSSO9ODnQPxzXZtQNHk=";
      }
    ];
    privateKey = "cCvDSo/JY5M76qalXJ/KIk9A13Z4wSv8+b1rxv+OEXc=";
    autostart = false;
  };

## Fingerprint
   services.fprintd.enable = true;

}
