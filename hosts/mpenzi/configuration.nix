# mpenzi: laptop van Maaike (overstap van Windows). Bewust een kale host: geen Hyprland,
# geen home-manager, geen lobos-overlays. Zie docs/mpenzi.md.
#
# Updates doet Wouter vanaf lobos:
#   nixos-rebuild switch --flake .#mpenzi --target-host wtoorren@mpenzi --sudo --ask-sudo-password
{ config, lib, pkgs, ... }:

let
  # Zelfde sleutel als `wtoorren` in secrets/secrets.nix.
  wtoorrenKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp";
in
{
  imports = [
    ./hardware-configuration.nix
    ./plasma.nix
    ./apps.nix
    ./rustdesk.nix
    ../../modules/printer-thuis.nix
    ../../modules/nebula.nix
  ];

  ########## BOOT ##########
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Swap staat op een eigen LUKS-volume; zonder deze regel wordt het niet ontgrendeld.
  boot.initrd.luks.devices."luks-ef7880b0-64cd-4dbb-8fa8-56faceca9e77".device = "/dev/disk/by-uuid/ef7880b0-64cd-4dbb-8fa8-56faceca9e77";

  ########## NETWERK ##########
  networking.hostName = "mpenzi";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  toorren.nebula.enable = true;

  # mpenzi.local op het thuisnetwerk.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = { enable = true; addresses = true; };
  };

  ########## TAAL EN TOETSENBORD ##########
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "nl_NL.UTF-8";
  i18n.extraLocaleSettings = lib.genAttrs [
    "LC_ADDRESS" "LC_IDENTIFICATION" "LC_MEASUREMENT" "LC_MONETARY" "LC_NAME"
    "LC_NUMERIC" "LC_PAPER" "LC_TELEPHONE" "LC_TIME"
  ] (_: "nl_NL.UTF-8");
  # Zoals Windows "US-International": dead keys voor ë, é, ' en ".
  services.xserver.xkb = { layout = "us"; variant = "intl"; };
  console.useXkbConfig = true;

  ########## GEBRUIKERS ##########
  users.users.maaike = {
    isNormalUser = true;
    description = "Maaike";
    # Bewust geen wheel: Maaike beheert het systeem niet zelf.
    extraGroups = [ "networkmanager" "lp" "scanner" ];
  };

  users.users.wtoorren = {
    isNormalUser = true;
    description = "Wouter";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ wtoorrenKey ];
  };

  ########## SSH ##########
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  ########## GELUID ##########
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  ########## ONDERHOUD ##########
  nixpkgs.config.allowUnfree = true;
  services.fwupd.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Nodig voor `--target-host wtoorren@mpenzi`: de closure wordt ongesigneerd gekopieerd.
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "26.05";
}
