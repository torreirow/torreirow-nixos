{ config, lib, pkgs, ... }:

{
  # Power management en suspend fixes voor lobos
  # Deze laptop ondersteunt alleen Modern Standby (S0ix/s2idle), niet S3

  # Kernel parameters voor betere S0ix werking
  boot.kernelParams = [
    # Disable problematic ACPI features that can prevent suspend
    "acpi_osi=Linux"

    # Better power management for AMD
    "amd_pstate=active"

    # Disable USB autosuspend during sleep (prevents wake issues)
    "usbcore.autosuspend=-1"
  ];

  # Power management settings
  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  # Services om netwerk te herstarten na suspend
  # Dit lost het probleem op waarbij wifi disabled blijft na suspend poging
  systemd.services.network-resume = {
    description = "Restart network services after suspend";
    wantedBy = [ "suspend.target" ];
    after = [ "suspend.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart NetworkManager.service";
    };
  };

  # Expliciet wifi driver herladen na suspend
  systemd.services.wifi-resume = {
    description = "Reload wifi driver after suspend";
    wantedBy = [ "suspend.target" ];
    after = [ "suspend.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.kmod}/bin/modprobe -r ath11k_pci && sleep 1 && ${pkgs.kmod}/bin/modprobe ath11k_pci'";
    };
  };

  # TLP voor betere power management (optioneel, kan conflicteren met powertop)
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     # Suspend mode
  #     DISK_IDLE_SECS_ON_AC = 0;
  #     DISK_IDLE_SECS_ON_BAT = 2;
  #
  #     # USB autosuspend
  #     USB_AUTOSUSPEND = 0;
  #
  #     # Wifi power saving
  #     WIFI_PWR_ON_AC = "off";
  #     WIFI_PWR_ON_BAT = "off";
  #   };
  # };
}
