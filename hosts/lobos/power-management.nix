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

  # Laadlimiet batterij: herstel instelling bij reboot vanuit /var/lib/battery-threshold
  systemd.services.battery-charge-threshold = {
    description = "Restore battery charge threshold";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'cat /var/lib/battery-threshold > /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
    };
  };

  # Maak state-bestand aan met standaard 100% als het nog niet bestaat
  systemd.tmpfiles.rules = [
    "f /var/lib/battery-threshold 0666 root root - 100"
  ];

  # Sta gebruiker toe om laadlimiet in te stellen zonder wachtwoord
  security.sudo.extraRules = [{
    users = [ "wtoorren" ];
    commands = [{
      command = "${pkgs.coreutils}/bin/tee /sys/class/power_supply/BAT0/charge_control_end_threshold";
      options = [ "NOPASSWD" ];
    }];
  }];

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
