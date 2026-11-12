# farol: de altijd-aan Nebula-lighthouse op AWS EC2 (eu-central-1, t3a.nano).
#
# Draait op de officiële NixOS-AMI en wordt bijgewerkt met
#   nixos-rebuild switch --flake .#farol --target-host root@farol.toorren.net
# Daarom blijven `nix` en `system.switch` (en dus perl) aan. De strippings hieronder zijn
# de veilige subset uit het smol-lab (wearetechnative/smol-nixos-base-image-nivis-ec2-experiment):
# documentatie, SSM-agent en amazon-init eruit; niks wat de activatie nodig heeft.
{ config, lib, pkgs, ... }:

let
  # Zelfde beheersleutel als modules/wtoorren-admin.nix (rbw: toorren-lobos-ed25519).
  wtoorrenKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp";
in
{
  imports = [
    # ENA/NVMe, growPartition, /dev/disk/by-label/nixos, EC2 metadata, sshd. De module
    # wordt in flake.nix toegevoegd (een `${pkgs.path}` hier zou recursie geven).
    ../../modules/nebula.nix
  ];

  networking.hostName = "farol";
  # dhcpcd zet anders de transient hostname op de EC2-DNS-naam (ip-172-31-...).
  networking.dhcpcd.extraConfig = "nohook hostname";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "26.05";
  time.timeZone = "Europe/Amsterdam";

  # --- beheer ---------------------------------------------------------------
  users.users.wtoorren = {
    isNormalUser = true;
    description = "Wouter";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ wtoorrenKey ];
  };
  # Root is de bootstrap (eerste deploy); daarna gaat alles via wtoorren.
  users.users.root.openssh.authorizedKeys.keys = [ wtoorrenKey ];
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Nodig voor `nixos-rebuild --target-host`: de closure komt ongesigneerd binnen.
  nix.settings = {
    trusted-users = [ "@wheel" ];
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  boot.loader.grub.configurationLimit = 3;

  # --- klein houden ----------------------------------------------------------
  documentation.enable = false;
  environment.systemPackages = [ pkgs.curl ]; # IMDS / DNS-updater
  i18n.supportedLocales = [ "C.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
  boot.initrd.compressor = "xz";
  services.amazon-ssm-agent.enable = lib.mkForce false;
  systemd.services.amazon-init.enable = lib.mkForce false;
  zramSwap.enable = true;

  # --- Nebula ----------------------------------------------------------------
  # Zonder secrets/nebula-farol.{crt,key}.age blijft Nebula automatisch uit.
  toorren.nebula.enable = true;
}
