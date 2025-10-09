{ config, pkgs,... }:

{
  environment.systemPackages = with pkgs; [
    chkrootkit
  ];

  systemd.services.chkrootkit = {
    description = "Run chkrootkit";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.chkrootkit}/bin/chkrootkit";
      StandardOutput = "append:/var/log/chkrootkit.log";
      StandardError = "append:/var/log/chkrootkit.log";
      };
      };

      systemd.timers.chkrootkit = {
        description = "Daily chkrootkit run";
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = "daily";
        timerConfig.Persistent = true;
        };

      }
