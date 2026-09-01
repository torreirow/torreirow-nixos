{ config, pkgs, lib, ... }:

# Dagelijkse, versleutelde, incrementele off-site backup naar AWS S3 met rustic.
# - Databases worden logisch gedumpt (pg_dumpall / mysqldump / sqlite .backup) naar
#   /var/backup/db en meegenomen in de backup; live DB-bestanden worden uitgesloten.
# - rustic praat DIRECT met S3 via opendal-s3 (geen mountpoint-s3/FUSE).
# - Creds via agenix env-file + ${VAR}-substitutie; repo-pw via agenix password-file.
# Zie openspec/changes/add-rustic-s3-backup/design.md voor de onderbouwing.

let
  stagingDir = "/var/backup/db";
  configDir = "/etc/rustic";
  profileName = "malandro";

  rusticBin = "${pkgs.rustic}/bin/rustic";
  # -P <naam> vindt <naam>.toml in de working directory (=configDir).
  rusticCmd = "${rusticBin} -P ${profileName} --profile-substitute-env";

  # Niet-geheim repo-profiel. De echte AWS-keys komen op runtime uit de
  # EnvironmentFile en worden via ${VAR} gesubstitueerd (getest: ${VAR} werkt,
  # {{VAR}} niet). Alleen placeholders staan in de nix-store.
  rusticProfile = pkgs.writeText "${profileName}.toml" ''
    [repository]
    repository = "opendal:s3"
    password-file = "/run/agenix/rustic-repo-password"

    [repository.options]
    bucket = "wto-s3-bucket"
    region = "eu-central-1"
    endpoint = "https://s3.eu-central-1.amazonaws.com"
    root = "/rustic-backup/malandro"
    access_key_id = "''${AWS_ACCESS_KEY_ID}"
    secret_access_key = "''${AWS_SECRET_ACCESS_KEY}"
  '';

  # File-level backup-manifest: twee roots + de DB-dumps.
  backupSources = [
    stagingDir
    # /var/lib container-state
    "/var/lib/homeassistant"
    "/var/lib/vaultwarden"
    "/var/lib/zigbee2mqtt"
    "/var/lib/signal-cli"
    "/var/lib/wg-easy"
    "/var/lib/baikal"
    "/var/lib/mmdl"
    "/var/lib/mosquitto"
    # gecureerd /data/external
    "/data/external/docseal"
    "/data/external/erugo"
    "/data/external/wallos"
    "/data/external/invoiceplane-docker"
    "/data/external/pihole"
    "/data/external/castopod"
    "/data/external/dockerlibs/volumes"
    "/data/external/tmp/paperless"
  ];

  # rustic: !pattern = EXCLUDE (getest). Al het overige wordt default meegenomen.
  excludeGlobs = [
    "!/var/lib/vaultwarden/db.sqlite3"      # live DB → dump i.p.v.
    "!/var/lib/vaultwarden/db.sqlite3-wal"
    "!/var/lib/vaultwarden/db.sqlite3-shm"
    "!/var/lib/vaultwarden/icon_cache"      # regenereerbaar
    "!/var/lib/vaultwarden/_temp"
    "!/data/external/tmp/paperless/paperless-ngx/consume"  # transient
    "!/data/external/tmp/paperless/paperless-ngx/export"
  ];

  sourceArgs = lib.escapeShellArgs backupSources;
  globArgs = lib.concatMapStringsSep " "
    (g: "--glob ${lib.escapeShellArg g}") excludeGlobs;

  # Faal-notificatie via de lokale signal-cli REST API (zelfde afzender/ontvanger
  # als Home Assistant's signal_maria). Best-effort: faalt de Signal-API, dan
  # blokkeert dat de OnFailure-handler niet (|| true).
  signalApi = "http://127.0.0.1:8088/v2/send";
  signalSender = "+31612652352";      # geregistreerd account op de server
  signalRecipient = "+31636201589";   # zelfde ontvanger als HA signal_maria
  notifyScript = pkgs.writeShellScript "rustic-notify-failure" ''
    set -u
    unit="''${1:-onbekend}"
    host="$(${pkgs.nettools}/bin/hostname)"
    msg="⚠️ Backup-fout op ''${host}: unit ''${unit} gefaald. Zie: journalctl -u ''${unit}"
    ${pkgs.jq}/bin/jq -nc \
      --arg m "$msg" --arg n "${signalSender}" --arg r "${signalRecipient}" \
      '{message: $m, number: $n, recipients: [$r]}' \
      | ${pkgs.curl}/bin/curl -s --max-time 30 -X POST "${signalApi}" \
          -H 'Content-Type: application/json' --data @- >/dev/null || true
  '';

  pgDumpScript = pkgs.writeShellScript "pg-dump" ''
    set -euo pipefail
    umask 077
    tmp="${stagingDir}/pg-all.sql.zst.tmp"
    out="${stagingDir}/pg-all.sql.zst"
    ${pkgs.util-linux}/bin/runuser -u postgres -- \
      ${config.services.postgresql.package}/bin/pg_dumpall --clean --if-exists \
      | ${pkgs.zstd}/bin/zstd -q -f -o "$tmp"
    mv -f "$tmp" "$out"
  '';

  mariadbDumpScript = pkgs.writeShellScript "mariadb-dump" ''
    set -euo pipefail
    umask 077
    tmp="${stagingDir}/mysql-all.sql.zst.tmp"
    out="${stagingDir}/mysql-all.sql.zst"
    ${config.services.mysql.package}/bin/mysqldump \
      --all-databases --single-transaction --routines --triggers --events \
      | ${pkgs.zstd}/bin/zstd -q -f -o "$tmp"
    mv -f "$tmp" "$out"
  '';

  vaultwardenDumpScript = pkgs.writeShellScript "vaultwarden-dump" ''
    set -euo pipefail
    umask 077
    tmp="${stagingDir}/vaultwarden.sqlite3.tmp"
    out="${stagingDir}/vaultwarden.sqlite3"
    rm -f "$tmp"
    ${pkgs.sqlite}/bin/sqlite3 /var/lib/vaultwarden/db.sqlite3 ".backup '$tmp'"
    mv -f "$tmp" "$out"
  '';

  backupScript = pkgs.writeShellScript "rustic-backup" ''
    set -euo pipefail
    cd ${configDir}
    # Idempotente init: repoinfo faalt op een nog niet bestaande repo.
    if ! ${rusticCmd} repoinfo >/dev/null 2>&1; then
      ${rusticCmd} init
    fi
    ${rusticCmd} backup --host ${profileName} ${sourceArgs} ${globArgs}
    ${rusticCmd} forget --filter-host ${profileName} \
      --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune
  '';

  # Gemeenschappelijke serviceConfig voor de dump-oneshots (draaien als root).
  dumpService = name: script: {
    description = "${name} dump voor rustic backup";
    onFailure = [ "rustic-notify@${name}.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = script;
    };
  };
in
{
  ###### Secrets ######
  age.secrets.rustic-s3-env = {
    file = ../secrets/rustic-s3-env.age;
    path = "/run/agenix/rustic-s3-env";
    mode = "0400";
  };
  age.secrets.rustic-repo-password = {
    file = ../secrets/rustic-repo-password.age;
    path = "/run/agenix/rustic-repo-password";
    mode = "0400";
  };
  ###### Staging-dir + profiel ######
  systemd.tmpfiles.rules = [
    "d /var/backup 0700 root root -"
    "d ${stagingDir} 0700 root root -"
  ];

  environment.etc."rustic/${profileName}.toml".source = rusticProfile;

  ###### Faal-notificatie (template-unit) ######
  systemd.services."rustic-notify@" = {
    description = "Telegram-notificatie bij backup-fout (%i)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${notifyScript} %i";
    };
  };

  ###### Dump-services ######
  systemd.services.pg-dump = dumpService "pg-dump" pgDumpScript;
  systemd.services.mariadb-dump = dumpService "mariadb-dump" mariadbDumpScript;
  systemd.services.vaultwarden-dump = dumpService "vaultwarden-dump" vaultwardenDumpScript;

  ###### Hoofd-backup-service ######
  systemd.services.rustic-backup = {
    description = "Rustic backup naar S3 (Vaultwarden + DBs + /data)";
    after = [
      "pg-dump.service"
      "mariadb-dump.service"
      "vaultwarden-dump.service"
      "network-online.target"
    ];
    wants = [
      "pg-dump.service"
      "mariadb-dump.service"
      "vaultwarden-dump.service"
      "network-online.target"
    ];
    onFailure = [ "rustic-notify@rustic-backup.service" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = configDir;
      EnvironmentFile = "/run/agenix/rustic-s3-env";
      TimeoutStartSec = "infinity";
      # Lage prioriteit: verstoor de draaiende services niet.
      Nice = 10;
      IOSchedulingClass = "idle";
      ExecStart = backupScript;
    };
  };

  ###### Timer: dagelijks 03:00 ######
  systemd.timers.rustic-backup = {
    description = "Dagelijkse rustic backup om 03:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };
}
