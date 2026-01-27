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
    ../../modules/mariadb.nix
   #./gnome.nix
 ../../modules/monitoring
 ../../modules/hassio
 ./malandro-secrets.nix
 ../../modules/nginx.nix
 ../../modules/kpn-modem.nix
 ../../modules/vaultwarden.nix
 ../../modules/baikal.nix
 ../../modules/wg.nix
 ../../modules/nfs.nix
 ../../modules/monitoring
 ../../modules/erugo.nix
 ../../modules/postgres.nix
 ../../modules/paperless.nix
 ../../modules/acme.nix
 ../../modules/authelia.nix
 ../../modules/authelia-users.nix
 ../../modules/claude.nix
 ../../modules/pihole.nix
 ../../modules/magister/magister-service.nix
 ../../modules/ittools.nix
# ../../modules/castopod.nix
# ../../modules/crowdsec.nix
   # ../../modules/teamviewer.nix
 ];

 services.magister-sync = {
   enable = true;
   nginx = {
     enable = true;
     domain = "agenda.toorren.net";
     acmeHost = "toorren.net";
   };
 };



  nix.extraOptions = ''
    experimental-features = nix-command flakes
    '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-0d63b3e4-41ea-4a66-b020-c1f162b8a944"= {
    device = "/dev/disk/by-uuid/0d63b3e4-41ea-4a66-b020-c1f162b8a944";
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };
#  boot.kernelParams = [ "pci=nomsi" "acpi=off" ];
#  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_1;
  boot.supportedFilesystems = [ "ntfs" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.initrd.systemd.enable = true;
  security.tpm2.enable = true;
  security.sudo = {
    wheelNeedsPassword = false;
  };

  fileSystems."/data/external" = {
    device = "/dev/disk/by-uuid/bb0a5762-c7d8-4bf9-a350-0eb87379c880";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=10"
    ];
  };

	systemd.tmpfiles.rules = [
		"d /data/external 2775 root wheel -"
	];

  ########## NETWORKING ##########
  # Enable networking
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  networking.hostName = "malandro"; # Define your hostname.
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
  networking.firewall.allowedUDPPorts = [ 111 2049  5353 ]; # Spotify Connect
  networking.firewall.allowedTCPPorts = [ 111 2049 57621 ]; # Sync local tracks

  # Enable bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.package = pkgs.bluez;
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
#  services.mysql = {
#    enable = true;
#    package = pkgs.mariadb;
#  };


  ## NEW CONFIG



	  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  services.avahi.openFirewall = true;


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wtoorren = {
    isNormalUser = true;
    description = "Wouter van der Toorren";
    extraGroups = [ "wheel" "keys"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp wtoorren@lobos"
    ];
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
  services.openssh = {
    enable = true;
    banner =  ''
 __  __         _                    _
|  \/  |  __ _ | |  __ _  _ __    __| | _ __  ___
| |\/| | / _` || | / _` || '_ \  / _` || '__|/ _ \
| |  | || (_| || || (_| || | | || (_| || |  | (_) |
|_|  |_| \__,_||_| \__,_||_| |_| \__,_||_|   \___/
'';

    extraConfig = "LoginGracetime=2m";
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

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

  virtualisation.docker = {
    enable = true;
        daemon.settings = {
      data-root = "/data/external/dockerlibs";
    };
  };

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

  # Authelia gebruikers configuratie
  # Genereer password hash met: authelia crypto hash generate argon2 --password 'jouwwachtwoord'
  # Zie modules/authelia-users-README.md voor meer informatie
  
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
      "server string" = "malandro";
      "netbios name" = "malandro";
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
      "path" = "/data/backup";
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
services.xscreensaver = {
  enable = true;
};

#systemd.services."restart-network-on-sleep" = {
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

#networking.wg-quick.interfaces.wg0 = {
#    address = [
#      "172.27.66.3/24"
#    ];
#    peers = [
#      {
#        allowedIPs = [
#          "0.0.0.0/0"
#        ];
#        endpoint = "homeassistant.toorren.net:51820";
#        publicKey = "8TLZ86+PygfP3GzrBUiBtXOleSSO9ODnQPxzXZtQNHk=";
#      }
#    ];
#    privateKey = "cCvDSo/JY5M76qalXJ/KIk9A13Z4wSv8+b1rxv+OEXc=";
#  };

services.authelia.users = [
  {
    username = "wouter";
    displayname = "Wouter van der Toorren";
    email = "wouter@toorren.net";
    passwordHash = "$argon2id$v=19$m=65536,t=3,p=4$i3rOqBLo2Oy8OxfSWJB+pw$tcfwS0+IT8uV5Po9vSQqVxCHIeVfIKEm5uTVrIi8fwg";
    groups = [ "admins" "users" "monitoring" "network" ];
    disabled = false;
  }
];



}
