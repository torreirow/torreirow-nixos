{ config, pkgs, lib, ... }:

# Eigen JuiceFS-volume `immich` voor de Immich-originelen (zie modules/immich.nix en
# docs/immich.md). Anders dan de Nextcloud-JuiceFS (juicefs-nextcloud-mount.nix) staat de
# metadata hier in de LOKALE PostgreSQL: bobadela1 gaat 's nachts uit en malandro mount die
# volume alleen read-only.
#
#   data:     s3://wto-s3-bucket/immich/   (volumenaam = prefix; IAM-user juicefs-immich
#                                           mag alleen dat prefix)
#   metadata: PostgreSQL juicefs_immich, rol juicefs_immich, peer-auth van root
#   mount:    /data/juicefs-immich (rw), cache /var/cache/juicefs-immich
#   crypto:   aes256gcm-rsa; de RSA-sleutel staat versleuteld in de metadata, mounten vraagt
#             alleen JFS_RSA_PASSPHRASE. De PEM staat als reserve in agenix.

let
  volume = "immich";
  mountPoint = "/data/juicefs-immich";
  cacheDir = "/var/cache/juicefs-immich";
  # Unix-socket + peer-auth (identMap root -> juicefs_immich): geen wachtwoord in de store.
  metaUrl = "postgres://juicefs_immich@/juicefs_immich?host=/run/postgresql&sslmode=disable";
  bucket = "https://wto-s3-bucket.s3.eu-central-1.amazonaws.com";
  juicefs = "${pkgs.juicefs}/bin/juicefs";
  # Map in het volume die Immich als mediaLocation gebruikt.
  mediaDir = "${mountPoint}/immich";

  # Eenmalig formatteren; doet niets zodra het volume bestaat.
  formatScript = pkgs.writeShellScript "juicefs-immich-format" ''
    set -euo pipefail
    if ${juicefs} status "${metaUrl}" >/dev/null 2>&1; then
      exit 0
    fi
    ${juicefs} format --storage s3 --bucket ${bucket} \
      --encrypt-rsa-key ${config.age.secrets.juicefs-immich-rsa-key.path} \
      --trash-days 30 "${metaUrl}" ${volume}
  '';

  # Wacht tot de FUSE-mount er echt is, zodat `After=juicefs-immich.service` betekent
  # dat de mount klaar is. Maakt daarna de Immich-map aan.
  waitScript = pkgs.writeShellScript "juicefs-immich-wait" ''
    set -euo pipefail
    for _ in $(seq 1 60); do
      if ${pkgs.util-linux}/bin/mountpoint -q ${mountPoint}; then
        install -d -m 0700 -o ${config.services.immich.user} -g ${config.services.immich.group} ${mediaDir}
        exit 0
      fi
      sleep 1
    done
    echo "JuiceFS-mount ${mountPoint} kwam niet op" >&2
    exit 1
  '';
in
{
  # ACCESS_KEY/SECRET_KEY (IAM-user juicefs-immich, alleen prefix immich/).
  age.secrets.juicefs-immich-env = {
    file = ../secrets/juicefs-immich-env.age;
    mode = "0400";
  };
  # JFS_RSA_PASSPHRASE=…
  age.secrets.juicefs-immich-passphrase = {
    file = ../secrets/juicefs-immich-passphrase.age;
    mode = "0400";
  };
  # PEM (versleuteld met de wachtwoordzin); alleen nodig bij `juicefs format`.
  age.secrets.juicefs-immich-rsa-key = {
    file = ../secrets/juicefs-immich-rsa-key.age;
    mode = "0400";
  };

  services.postgresql = {
    ensureDatabases = [ "juicefs_immich" ];
    ensureUsers = [{
      name = "juicefs_immich";
      ensureDBOwnership = true;
    }];
    identMap = ''
      juicefs_immich root juicefs_immich
    '';
    # Vóór de algemene `local all all peer`-regel, anders wint die (root != juicefs_immich).
    # Prioriteit 10 omdat modules/docseal.nix de hele authentication met mkOverride 10 zet;
    # gelijke prioriteit voegt samen, lagere zou genegeerd worden.
    authentication = lib.mkOverride 10 (lib.mkBefore ''
      local juicefs_immich juicefs_immich peer map=juicefs_immich
    '');
  };

  environment.systemPackages = [ pkgs.juicefs ];

  systemd.tmpfiles.rules = [
    "d ${mountPoint} 0755 root root -"
    "d ${cacheDir} 0700 root root -"
  ];

  systemd.services.juicefs-immich-format = {
    description = "JuiceFS-volume ${volume} eenmalig formatteren";
    after = [ "postgresql.target" "network-online.target" ];
    requires = [ "postgresql.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = [
        config.age.secrets.juicefs-immich-env.path
        config.age.secrets.juicefs-immich-passphrase.path
      ];
      ExecStart = formatScript;
    };
  };

  systemd.services.juicefs-immich = {
    description = "JuiceFS-mount ${mountPoint} (Immich-originelen, S3 immich/)";
    after = [ "juicefs-immich-format.service" "postgresql.target" "network-online.target" ];
    requires = [ "juicefs-immich-format.service" "postgresql.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      EnvironmentFile = [
        config.age.secrets.juicefs-immich-env.path
        config.age.secrets.juicefs-immich-passphrase.path
      ];
      ExecStart =
        "${juicefs} mount ${metaUrl} ${mountPoint} "
        + "--cache-dir ${cacheDir} --cache-size 5120 -o allow_other";
      ExecStartPost = waitScript;
      ExecStop = "${pkgs.util-linux}/bin/umount ${mountPoint}";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
