{ config, pkgs, lib, ... }:

let
  cfg = config.services.wifi-ssid-monitor;

  # Bash-array met de te volgen SSID's, veilig ge-escaped vanuit de NixOS-optie.
  watchArray = lib.concatMapStringsSep " " lib.escapeShellArg cfg.watchSSIDs;

  # Kort scan-script: draait 1x per timer-tick, schrijft metrics en stopt weer.
  # writeShellApplication voegt automatisch `set -euo pipefail` toe en draait
  # shellcheck tijdens de build.
  wifiScanScript = pkgs.writeShellApplication {
    name = "wifi-ssid-scan";
    runtimeInputs = [ pkgs.networkmanager pkgs.coreutils pkgs.gawk ];
    text = ''
      OUT=/var/lib/prometheus-node-exporter-textfiles/wifi_scan.prom
      WATCH=( ${watchArray} )

      scan="$(mktemp)"
      trap 'rm -f "$scan"' EXIT

      # Actieve scan van zichtbare accesspoints. -t = terse (":"-gescheiden velden).
      nmcli -t -f SSID,SIGNAL dev wifi list --rescan yes > "$scan"

      {
        echo "# HELP wifi_ssid_visible Of de gevolgde SSID zichtbaar was bij de laatste scan (1) of niet (0)"
        echo "# TYPE wifi_ssid_visible gauge"
        echo "# HELP wifi_signal_percent Sterkste signaal (0-100) van accesspoints met deze SSID"
        echo "# TYPE wifi_signal_percent gauge"

        for ssid in "''${WATCH[@]}"; do
          # Sterkste SIGNAL over alle regels die exact op deze SSID matchen.
          # $1==s is een letterlijke string-vergelijking (geen regex).
          sig="$(awk -F: -v s="$ssid" '$1==s && $2>m {m=$2} END{print m+0}' "$scan")"
          if awk -F: -v s="$ssid" '$1==s{f=1} END{exit !f}' "$scan"; then
            printf 'wifi_ssid_visible{ssid="%s"} 1\n' "$ssid"
            printf 'wifi_signal_percent{ssid="%s"} %s\n' "$ssid" "$sig"
          else
            printf 'wifi_ssid_visible{ssid="%s"} 0\n' "$ssid"
          fi
        done

        # Staleness-signaal: alleen geschreven als het script volledig doorloopt.
        echo "# HELP wifi_scan_last_success_timestamp_seconds Unixtime van de laatste geslaagde scan"
        echo "# TYPE wifi_scan_last_success_timestamp_seconds gauge"
        printf 'wifi_scan_last_success_timestamp_seconds %s\n' "$(date +%s)"
      } > "$OUT.tmp"

      # Atomair vervangen (zelfde filesystem) zodat Prometheus nooit een half bestand leest.
      mv "$OUT.tmp" "$OUT"
    '';
  };

in {
  options.services.wifi-ssid-monitor = {
    enable = lib.mkEnableOption "periodieke wifi-SSID-monitor die metrics naar de node-exporter textfile collector schrijft";

    watchSSIDs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "Peperbus" ];
      example = [ "Peperbus" "Gastnetwerk" ];
      description = "Lijst van SSID's die gemonitord worden. Toevoegen/verwijderen vereist geen wijziging aan het script of de alert-regels.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      example = "60s";
      description = "Interval tussen scans (systemd OnUnitActiveSec-formaat).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wifi-ssid-scan = {
      description = "Wifi SSID scan -> Prometheus textfile collector";
      after = [ "NetworkManager.service" ];
      wants = [ "NetworkManager.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${wifiScanScript}/bin/wifi-ssid-scan";
      };
    };

    systemd.timers.wifi-ssid-scan = {
      description = "Timer voor de wifi-SSID-scan";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.interval;
        Unit = "wifi-ssid-scan.service";
      };
    };
  };
}
