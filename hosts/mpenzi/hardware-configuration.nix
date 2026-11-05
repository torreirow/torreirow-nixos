# Overgenomen van de laptop (nixos-generate-config). De LUKS-regel voor swap stond in de
# originele configuration.nix en staat in configuration.nix van deze host.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/luks-b1fa5503-292a-474c-ba08-8358d4b06242";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-b1fa5503-292a-474c-ba08-8358d4b06242".device = "/dev/disk/by-uuid/b1fa5503-292a-474c-ba08-8358d4b06242";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/47CC-A5BA";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/mapper/luks-ef7880b0-64cd-4dbb-8fa8-56faceca9e77"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
