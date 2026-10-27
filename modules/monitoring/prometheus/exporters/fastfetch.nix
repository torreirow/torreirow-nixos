{ config, pkgs, lib, ... }:

# Systeeminfo à la fastfetch als Prometheus-metric, voor de tabel in het Server Health-dashboard.
# Eén regel per fastfetch-veld:
#   node_fastfetch_info{order="03",key="Kernel",value="6.18.55"} 1
# via de node-exporter textfile collector (zelfde patroon als wifi-ssid.nix).

let
  # Fastfetch-config. Weggelaten t.o.v. de interactieve versie: title/user, Shell, Terminal en Date
  # (zeggen niets in een systemd-service) en Updates (op NixOS alleen "run: nixos-rebuild").
  # "Reboot" is NixOS-specifiek: nodig als de geactiveerde generatie een andere kernel,
  # initrd of kernelmodules heeft dan waarmee geboot is.
  fastfetchConfig = pkgs.writeText "fastfetch-prometheus.jsonc" (builtins.toJSON {
    logo.type = "none";
    display.separator = ": ";
    modules = [
      { type = "command"; key = "OS";
        text = ''. /etc/os-release && echo "$NAME ''${BUILD_ID:-$VERSION_ID} ''${VERSION_CODENAME:+($VERSION_CODENAME) }$(uname -m)"''; }
      { type = "host"; key = "Host"; }
      { type = "command"; key = "Hostname"; text = "cat /etc/hostname"; }
      { type = "kernel"; key = "Kernel"; format = "{release}"; }
      { type = "command"; key = "Kernel Built";
        text = "uname -v | awk '{print $6, $5, $9}' | xargs -I{} date -d '{}' '+%Y-%m-%d'"; }
      { type = "command"; key = "Kernel Latest";
        text = ''branch=$(uname -r | cut -d. -f1-2); curl -s --max-time 5 https://www.kernel.org/releases.json | jq -r --arg b "$branch." '[.releases[] | select(.version | startswith($b))] | .[0] | "\(.version) (\(.released.isodate))"' ''; }
      { type = "uptime"; key = "Uptime"; }
      { type = "packages"; key = "Packages"; }
      { type = "command"; key = "Last Update";
        text = "stat -c '%y' /nix/var/nix/profiles/system | cut -d. -f1"; }
      { type = "command"; key = "Reboot";
        text = ''for f in kernel initrd kernel-modules; do [ "$(readlink -f /run/booted-system/$f)" = "$(readlink -f /run/current-system/$f)" ] || { echo "REQUIRED ($f gewijzigd)"; exit 0; }; done; echo "not required"''; }
      { type = "cpu"; key = "CPU"; format = "{name} ({cores-logical}) @ {freq-max}"; }
      { type = "gpu"; key = "GPU"; }
      { type = "memory"; key = "Memory"; }
      { type = "disk"; key = "Disk (/)"; folders = "/"; }
      { type = "localip"; key = "Local IP"; showIpv4 = true; showIpv6 = false; }
      { type = "loadavg"; key = "Load"; }
    ];
  });

  fastfetchScript = pkgs.writeShellApplication {
    name = "fastfetch-textfile";
    # Ook voor de command-modules hierboven (die erven PATH van dit script). nix is nodig voor
    # de Packages-module (fastfetch telt via nix-store; zonder nix op PATH valt de regel weg).
    runtimeInputs = (with pkgs; [ fastfetch jq curl gawk coreutils findutils gnugrep ]) ++ [ config.nix.package ];
    text = ''
      OUT="''${FASTFETCH_PROM_OUT:-/var/lib/prometheus-node-exporter-textfiles/fastfetch.prom}"

      raw="$(mktemp)"
      trap 'rm -f "$raw"' EXIT
      fastfetch --config ${fastfetchConfig} --logo none --pipe true > "$raw"

      {
        echo "# HELP node_fastfetch_info Systeeminfo uit fastfetch; key/value als labels, order = volgorde"
        echo "# TYPE node_fastfetch_info gauge"
        # "Key: value"-regels → één metric per regel. tojson escapet " en \ zoals Prometheus wil;
        # stuurtekens eruit zodat er geen \t of \u-escapes in de labels komen.
        jq -Rnr '
          [inputs | select(length > 0) | capture("^(?<key>[^:]+): (?<value>.*)$")]
          | to_entries[]
          | "node_fastfetch_info{order=\"\((.key + 1) | tostring | if length < 2 then "0" + . else . end)\",key=\(.value.key | tojson),value=\(.value.value | gsub("[[:cntrl:]]"; "") | tojson)} 1"
        ' < "$raw"

        echo "# HELP node_fastfetch_last_success_timestamp_seconds Unixtime van de laatste geslaagde fastfetch-run"
        echo "# TYPE node_fastfetch_last_success_timestamp_seconds gauge"
        printf 'node_fastfetch_last_success_timestamp_seconds %s\n' "$(date +%s)"
      } > "$OUT.tmp"

      # Atomair vervangen zodat Prometheus nooit een half bestand leest.
      mv "$OUT.tmp" "$OUT"
    '';
  };
in
{
  systemd.services.fastfetch-textfile = {
    description = "Fastfetch-systeeminfo -> Prometheus textfile collector";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fastfetchScript}/bin/fastfetch-textfile";
    };
  };

  systemd.timers.fastfetch-textfile = {
    description = "Timer voor fastfetch-systeeminfo (elk uur)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1h";
      Unit = "fastfetch-textfile.service";
    };
  };
}
