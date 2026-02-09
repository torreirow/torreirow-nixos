{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.torrlinny-web;

  rsyncScript = pkgs.writeShellScript "torrlinny-sync.sh" ''
    set -euo pipefail

    SRC="${cfg.repoPath}/public/"
    STATEFILE="/var/lib/torrlinny-web/public.hash"

    mkdir -p "$(dirname "$STATEFILE")"

    if [ ! -d "$SRC" ]; then
      echo "public directory not found: $SRC"
      exit 0
    fi

    # Bepaal hash van alle bestanden (inhoud + pad)
    NEW_HASH=$(
      find "$SRC" -type f -print0 \
        | sort -z \
        | xargs -0 sha256sum \
        | sha256sum \
        | awk '{print $1}'
    )

    if [ -f "$STATEFILE" ]; then
      OLD_HASH=$(cat "$STATEFILE")
    else
      OLD_HASH=""
    fi

    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
      echo "Changes detected, running rsync…"

      ${pkgs.rsync}/bin/rsync -az --delete \
        -e "${pkgs.openssh}/bin/ssh -i ${cfg.sshKey} -o StrictHostKeyChecking=accept-new" \
        "$SRC" \
        "${cfg.remoteTarget}/"

      echo "$NEW_HASH" > "$STATEFILE"
    else
      echo "No changes in public/, skipping rsync"
    fi
  '';
in
{
  ###### opties ######
  options.services.torrlinny-web = {
    enable = mkEnableOption "Torrlinny web rsync service";

    repoPath = mkOption {
      type = types.path;
      example = "/home/wtoorren/data/git/torreirow/torrlinny";
      description = "Local torrlinny git repository path";
    };

    remoteTarget = mkOption {
      type = types.str;
      example = "malandro:/var/www/html/torrlinny";
      description = "Remote rsync destination (ssh syntax)";
    };

    sshKey = mkOption {
      type = types.path;
      example = "/root/.ssh/torrlinny_ed25519";
      description = "SSH private key used for rsync";
    };

    user = mkOption {
      type = types.str;
      default = "root";
      description = "User that runs the service";
    };
  };

  ###### implementatie ######
  config = mkIf cfg.enable {

    systemd.services.torrlinny-web = {
      description = "Torrlinny public/ rsync deploy";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        ExecStart = rsyncScript;
      };
    };

    systemd.timers.torrlinny-web = {
      description = "Run Torrlinny web deploy every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        Unit = "torrlinny-web.service";
      };
    };
  };
}

